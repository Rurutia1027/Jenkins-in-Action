//go:build integration

package integration

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"bugtracker-backend/internal/db"
	"bugtracker-backend/internal/handlers"
	"bugtracker-backend/internal/models"

	"github.com/gorilla/mux"
	"github.com/stretchr/testify/require"
)

func openDB(t *testing.T, path string) {
	t.Helper()
	db.SetDatabasePath(path)
	require.NoError(t, db.Init())
}

func newAPI(t *testing.T) *httptest.Server {
	t.Helper()
	r := mux.NewRouter()
	r.HandleFunc("/api/health", handlers.HealthCheck).Methods("GET")
	handlers.RegisterRoutes(r.PathPrefix("/api").Subrouter())
	srv := httptest.NewServer(r)
	t.Cleanup(srv.Close)
	return srv
}

func doJSON(t *testing.T, method, url string, body any) *http.Response {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		require.NoError(t, err)
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, url, rdr)
	require.NoError(t, err)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	res, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	return res
}

func decodeJSON(t *testing.T, res *http.Response, dest any) {
	t.Helper()
	defer res.Body.Close()
	require.NoError(t, json.NewDecoder(res.Body).Decode(dest))
}

func TestHealthAndBugLifecycle_ThroughBbolt(t *testing.T) {
	path := filepath.Join(t.TempDir(), "bugs.db")
	openDB(t, path)
	t.Cleanup(db.Cleanup)
	srv := newAPI(t)

	health := doJSON(t, http.MethodGet, srv.URL+"/api/health", nil)
	require.Equal(t, http.StatusOK, health.StatusCode)
	var healthBody map[string]any
	decodeJSON(t, health, &healthBody)
	require.Equal(t, "ok", healthBody["status"])

	created := doJSON(t, http.MethodPost, srv.URL+"/api/bugs", models.CreateBugRequest{
		Title:       "INT Login broken",
		Description: "Handler must persist this in bbolt",
		Status:      "Open",
		Priority:    "High",
	})
	require.Equal(t, http.StatusCreated, created.StatusCode)
	var bug models.Bug
	decodeJSON(t, created, &bug)
	require.NotZero(t, bug.ID)
	require.Equal(t, "INT Login broken", bug.Title)
	require.Equal(t, "Open", bug.Status)
	require.Equal(t, "High", bug.Priority)

	listed := doJSON(t, http.MethodGet, srv.URL+"/api/bugs", nil)
	require.Equal(t, http.StatusOK, listed.StatusCode)
	var bugs []models.Bug
	decodeJSON(t, listed, &bugs)
	require.NotEmpty(t, bugs)

	got := doJSON(t, http.MethodGet, fmt.Sprintf("%s/api/bugs/%d", srv.URL, bug.ID), nil)
	require.Equal(t, http.StatusOK, got.StatusCode)
	var stored models.Bug
	decodeJSON(t, got, &stored)
	require.Equal(t, bug.ID, stored.ID)
	require.Equal(t, bug.Title, stored.Title)

	updated := doJSON(t, http.MethodPut, fmt.Sprintf("%s/api/bugs/%d", srv.URL, bug.ID), models.CreateBugRequest{
		Title:       "INT Login broken",
		Description: "Now in progress",
		Status:      "In Progress",
		Priority:    "Medium",
	})
	require.Equal(t, http.StatusOK, updated.StatusCode)
	var after models.Bug
	decodeJSON(t, updated, &after)
	require.Equal(t, "In Progress", after.Status)
	require.Equal(t, "Medium", after.Priority)

	commented := doJSON(t, http.MethodPost, fmt.Sprintf("%s/api/bugs/%d/comments", srv.URL, bug.ID), map[string]string{
		"author":  "Ada",
		"content": "Reproduced on iOS",
	})
	require.Equal(t, http.StatusCreated, commented.StatusCode)

	commentsRes := doJSON(t, http.MethodGet, fmt.Sprintf("%s/api/bugs/%d/comments", srv.URL, bug.ID), nil)
	require.Equal(t, http.StatusOK, commentsRes.StatusCode)
	var comments []models.Comment
	decodeJSON(t, commentsRes, &comments)
	require.Len(t, comments, 1)
	require.Equal(t, "Ada", comments[0].Author)
	require.Equal(t, "Reproduced on iOS", comments[0].Content)
	require.Equal(t, bug.ID, comments[0].BugID)

	deleted := doJSON(t, http.MethodDelete, fmt.Sprintf("%s/api/bugs/%d", srv.URL, bug.ID), nil)
	require.Equal(t, http.StatusNoContent, deleted.StatusCode)
	deleted.Body.Close()

	missing := doJSON(t, http.MethodGet, fmt.Sprintf("%s/api/bugs/%d", srv.URL, bug.ID), nil)
	require.Equal(t, http.StatusNotFound, missing.StatusCode)
	missing.Body.Close()
}

func TestBugSurvivesBboltReopen(t *testing.T) {
	path := filepath.Join(t.TempDir(), "bugs.db")
	openDB(t, path)
	srv := newAPI(t)

	created := doJSON(t, http.MethodPost, srv.URL+"/api/bugs", models.CreateBugRequest{
		Title:       "INT persist across restart",
		Description: "Must still be there after Init/Cleanup",
		Status:      "Open",
		Priority:    "Low",
	})
	require.Equal(t, http.StatusCreated, created.StatusCode)
	var bug models.Bug
	decodeJSON(t, created, &bug)
	require.NotZero(t, bug.ID)

	db.Cleanup()
	openDB(t, path)
	t.Cleanup(db.Cleanup)

	got := doJSON(t, http.MethodGet, fmt.Sprintf("%s/api/bugs/%d", srv.URL, bug.ID), nil)
	require.Equal(t, http.StatusOK, got.StatusCode)
	var stored models.Bug
	decodeJSON(t, got, &stored)
	require.Equal(t, bug.ID, stored.ID)
	require.Equal(t, "INT persist across restart", stored.Title)
	require.Equal(t, "Open", stored.Status)
}

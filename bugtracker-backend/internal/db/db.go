package db

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"bugtracker-backend/internal/models"

	"go.etcd.io/bbolt"
)

var (
	db             *bbolt.DB
	initialized    bool
	bugsBucket     = []byte("bugs")
	commentsBucket = []byte("comments")
	counterBucket  = []byte("counter")
	databasePath   = getDBPath()
)

func getDBPath() string {
	if path := os.Getenv("DB_PATH"); path != "" {
		return path
	}
	return "bugs.db"
}

func Init() error {
	if initialized {
		return fmt.Errorf("database already initialized")
	}

	var err error
	db, err = bbolt.Open(databasePath, 0600, nil)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	err = db.Update(func(tx *bbolt.Tx) error {
		_, err := tx.CreateBucketIfNotExists(bugsBucket)
		if err != nil {
			return fmt.Errorf("create bugs bucket: %w", err)
		}

		_, err = tx.CreateBucketIfNotExists(commentsBucket)
		if err != nil {
			return fmt.Errorf("create comments bucket: %w", err)
		}

		b, err := tx.CreateBucketIfNotExists(counterBucket)
		if err != nil {
			return fmt.Errorf("create counter bucket: %w", err)
		}
		if b.Get([]byte("bug_id")) == nil {
			if err := b.Put([]byte("bug_id"), itob(0)); err != nil {
				return fmt.Errorf("initialize bug counter: %w", err)
			}
		}

		return nil
	})
	if err != nil {
		return fmt.Errorf("failed to create buckets: %w", err)
	}

	log.Println("Database initialized successfully.")
	initialized = true
	return nil
}

// SeedIfEmpty inserts sample bugs when the store is empty.
// Used for local/docker demos so the UI is not blank on first start.
func SeedIfEmpty() error {
	if db == nil {
		return fmt.Errorf("database not initialized")
	}

	bugs, err := GetAllBugs()
	if err != nil {
		return err
	}
	if len(bugs) > 0 {
		return nil
	}

	now := time.Now()
	samples := []models.Bug{
		{
			Title:       "Login button unresponsive on mobile",
			Description: "Tapping Login on iOS Safari does nothing. Reproduced on iPhone 14.",
			Status:      "Open",
			Priority:    "High",
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			Title:       "Dashboard chart misaligned",
			Description: "Weekly summary bars overflow the card on screens narrower than 768px.",
			Status:      "In Progress",
			Priority:    "Medium",
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			Title:       "Typo in password reset email",
			Description: "Subject line says \"Reset you password\" instead of \"your\".",
			Status:      "Open",
			Priority:    "Low",
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			Title:       "Export CSV includes deleted bugs",
			Description: "Closed-and-deleted records still appear in the CSV export.",
			Status:      "Closed",
			Priority:    "Medium",
			CreatedAt:   now,
			UpdatedAt:   now,
		},
	}

	for i := range samples {
		if err := CreateBug(&samples[i]); err != nil {
			return fmt.Errorf("seed bug %q: %w", samples[i].Title, err)
		}
	}

	log.Printf("Seeded %d sample bugs", len(samples))
	return nil
}

func CreateBug(bug *models.Bug) error {
	if db == nil {
		return fmt.Errorf("database not initialized")
	}
	return db.Update(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bugsBucket)

		nextID, err := getNextID(tx)
		if err != nil {
			return err
		}

		bug.ID = nextID

		encoded, err := json.Marshal(bug)
		if err != nil {
			return fmt.Errorf("failed to marshal bug: %w", err)
		}

		return b.Put(itob(bug.ID), encoded)
	})
}

func GetBug(id int) (*models.Bug, error) {
	var bug models.Bug

	err := db.View(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bugsBucket)
		data := b.Get(itob(id))
		if data == nil {
			return fmt.Errorf("bug not found")
		}

		return json.Unmarshal(data, &bug)
	})

	if err != nil {
		return nil, err
	}

	return &bug, nil
}

func GetAllBugs() ([]*models.Bug, error) {
	bugs := make([]*models.Bug, 0)

	err := db.View(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bugsBucket)

		return b.ForEach(func(k, v []byte) error {
			var bug models.Bug
			if err := json.Unmarshal(v, &bug); err != nil {
				return fmt.Errorf("failed to unmarshal bug %s: %w", k, err)
			}
			bugs = append(bugs, &bug)
			return nil
		})
	})

	if err != nil {
		return nil, err
	}

	return bugs, nil
}

func DeleteBug(id int) error {
	return db.Update(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bugsBucket)
		if b == nil {
			return fmt.Errorf("bucket not found")
		}

		if b.Get(itob(id)) == nil {
			return fmt.Errorf("bug not found")
		}

		return b.Delete(itob(id))
	})
}

func Cleanup() {
	if db != nil {
		db.Close()
		db = nil
	}
	initialized = false
}

func getNextID(tx *bbolt.Tx) (int, error) {
	b := tx.Bucket(counterBucket)
	id := b.Get([]byte("lastBugID"))

	var nextID int
	if id == nil {
		nextID = 1
	} else {
		nextID = btoi(id) + 1
	}

	if err := b.Put([]byte("lastBugID"), itob(nextID)); err != nil {
		return 0, err
	}

	return nextID, nil
}

func itob(v int) []byte {
	b := make([]byte, 8)
	binary.BigEndian.PutUint64(b, uint64(v))
	return b
}

func btoi(b []byte) int {
	return int(binary.BigEndian.Uint64(b))
}

func UpdateBug(bug *models.Bug) error {
	return db.Update(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bugsBucket)

		existing := b.Get(itob(bug.ID))
		if existing == nil {
			return fmt.Errorf("bug not found")
		}

		bug.UpdatedAt = time.Now()

		encoded, err := json.Marshal(bug)
		if err != nil {
			return fmt.Errorf("failed to marshal bug: %w", err)
		}

		return b.Put(itob(bug.ID), encoded)
	})
}

func CleanupTestDB() error {
	if db == nil {
		return nil
	}

	err := db.Update(func(tx *bbolt.Tx) error {
		if err := tx.DeleteBucket(bugsBucket); err != nil {
			return err
		}
		if err := tx.DeleteBucket(commentsBucket); err != nil {
			return err
		}
		if err := tx.DeleteBucket(counterBucket); err != nil {
			return err
		}

		if _, err := tx.CreateBucket(bugsBucket); err != nil {
			return err
		}
		if _, err := tx.CreateBucket(commentsBucket); err != nil {
			return err
		}
		if _, err := tx.CreateBucket(counterBucket); err != nil {
			return err
		}
		return nil
	})

	return err
}

func DeleteAllBugs() (int, error) {
	var count int
	err := db.Update(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bugsBucket)
		if b == nil {
			count = 0
			return nil
		}
		count = b.Stats().KeyN

		if err := tx.DeleteBucket(bugsBucket); err != nil {
			return fmt.Errorf("delete bugs bucket: %w", err)
		}
		
		if _, err := tx.CreateBucket(bugsBucket); err != nil {
			return fmt.Errorf("create bugs bucket: %w", err)
		}

		c := tx.Bucket(counterBucket)
		if err := c.Put([]byte("lastBugID"), itob(0)); err != nil {
			return fmt.Errorf("reset bug counter: %w", err)
		}

		return nil
	})
	return count, err
}

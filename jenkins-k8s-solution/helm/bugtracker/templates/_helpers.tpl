{{/*
Expand the name of the chart.
*/}}
{{- define "bugtracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "bugtracker.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "bugtracker.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "bugtracker.labels" -}}
app.kubernetes.io/name: {{ include "bugtracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "bugtracker.backendName" -}}
{{ include "bugtracker.fullname" . }}-backend
{{- end }}

{{- define "bugtracker.frontendName" -}}
{{ include "bugtracker.fullname" . }}-frontend
{{- end }}

{{- define "bugtracker.image" -}}
{{- $img := . -}}
{{- printf "%s/%s:%s" $img.registry $img.repository $img.tag }}
{{- end }}

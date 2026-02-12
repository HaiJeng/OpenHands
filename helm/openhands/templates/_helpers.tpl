{{/*
Expand the name of the chart.
*/}}
{{- define "openhands.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openhands.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openhands.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openhands.labels" -}}
helm.sh/chart: {{ include "openhands.chart" . }}
{{ include "openhands.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openhands.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openhands.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openhands.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openhands.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap
*/}}
{{- define "openhands.configMapName" -}}
{{- if .Values.config.existingConfigmap }}
{{- .Values.config.existingConfigmap }}
{{- else }}
{{- printf "%s-config" (include "openhands.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret
*/}}
{{- define "openhands.secretName" -}}
{{- if .Values.secret.existingSecret }}
{{- .Values.secret.existingSecret }}
{{- else }}
{{- printf "%s-secret" (include "openhands.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the data PVC
*/}}
{{- define "openhands.dataPvcName" -}}
{{- if .Values.persistence.data.existingClaim }}
{{- .Values.persistence.data.existingClaim }}
{{- else }}
{{- printf "%s-data" (include "openhands.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the workspace PVC
*/}}
{{- define "openhands.workspacePvcName" -}}
{{- if .Values.persistence.workspace.existingClaim }}
{{- .Values.persistence.workspace.existingClaim }}
{{- else }}
{{- printf "%s-workspace" (include "openhands.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Merge environment variables from multiple sources
*/}}
{{- define "openhands.env" -}}
{{- $env := list }}
{{- /* Add default environment variables */ -}}
{{- $env = append $env (dict "name" "AGENT_SERVER_IMAGE_REPOSITORY" "value" printf "%s:%s" .Values.image.agentServer.repository .Values.image.agentServer.tag) }}
{{- $env = append $env (dict "name" "WORKSPACE_MOUNT_PATH" "value" .Values.openhands.workspace.base) }}
{{- $env = append $env (dict "name" "WORKSPACE_BASE" "value" .Values.openhands.workspace.base) }}
{{- $env = append $env (dict "name" "RUN_AS_OPENHANDS" "value" "true") }}
{{- $env = append $env (dict "name" "FILE_STORE" "value" .Values.openhands.fileStore.type) }}
{{- $env = append $env (dict "name" "FILE_STORE_PATH" "value" .Values.openhands.fileStore.path) }}
{{- $env = append $env (dict "name" "INIT_GIT_IN_EMPTY_WORKSPACE" "value" (printf "%t" .Values.openhands.workspace.initGit)) }}
{{- $env = append $env (dict "name" "SANDBOX_USER_ID" "value" "0") }}
{{- /* Add LLM configuration */ -}}
{{- if .Values.openhands.llm.model }}
{{- $env = append $env (dict "name" "LLM_MODEL" "value" .Values.openhands.llm.model) }}
{{- end }}
{{- if .Values.openhands.llm.apiKey }}
{{- $env = append $env (dict "name" "LLM_API_KEY" "value" .Values.openhands.llm.apiKey) }}
{{- end }}
{{- if .Values.openhands.llm.baseURL }}
{{- $env = append $env (dict "name" "LLM_BASE_URL" "value" .Values.openhands.llm.baseURL) }}
{{- end }}
{{- /* Add JWT secret */ -}}
{{- if .Values.openhands.jwtSecret }}
{{- $env = append $env (dict "name" "JWT_SECRET" "value" .Values.openhands.jwtSecret) }}
{{- end }}
{{- /* Add extra environment variables */ -}}
{{- range .Values.extraEnv }}
{{- $env = append $env . }}
{{- end }}
{{- /* Add secret-based environment variables */ -}}
{{- if .Values.secret.enabled }}
{{- range $key, $value := .Values.secret.data }}
{{- $env = append $env (dict "name" $key "valueFrom" (dict "secretKeyRef" (dict "name" (include "openhands.secretName" $) "key" $key))) }}
{{- end }}
{{- end }}
{{- $env | toYaml }}
{{- end }}

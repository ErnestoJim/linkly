{{- define "linkly.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "linkly.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "linkly.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "linkly.labels" -}}
helm.sh/chart: {{ include "linkly.chart" . }}
{{ include "linkly.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "linkly.selectorLabels" -}}
app.kubernetes.io/name: {{ include "linkly.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Nombres, labels y selectores por componente (api / worker / elasticmq),
para no repetir "-api"/"-worker" y el component label en cada plantilla.
*/}}
{{- define "linkly.api.fullname" -}}
{{ include "linkly.fullname" . }}-api
{{- end -}}

{{- define "linkly.worker.fullname" -}}
{{ include "linkly.fullname" . }}-worker
{{- end -}}

{{- define "linkly.elasticmq.fullname" -}}
{{ include "linkly.fullname" . }}-elasticmq
{{- end -}}

{{- define "linkly.api.selectorLabels" -}}
{{ include "linkly.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end -}}

{{- define "linkly.worker.selectorLabels" -}}
{{ include "linkly.selectorLabels" . }}
app.kubernetes.io/component: worker
{{- end -}}

{{- define "linkly.elasticmq.selectorLabels" -}}
{{ include "linkly.selectorLabels" . }}
app.kubernetes.io/component: elasticmq
{{- end -}}

{{- define "linkly.api.labels" -}}
{{ include "linkly.labels" . }}
app.kubernetes.io/component: api
{{- end -}}

{{- define "linkly.worker.labels" -}}
{{ include "linkly.labels" . }}
app.kubernetes.io/component: worker
{{- end -}}

{{- define "linkly.elasticmq.labels" -}}
{{ include "linkly.labels" . }}
app.kubernetes.io/component: elasticmq
{{- end -}}

{{/*
securityContext restrictivo compartido por los contenedores propios del
chart (api, worker, job de migraciones). Los subcharts de terceros
(postgresql, redis) y el contenedor de ElasticMQ usan sus propios
defaults.
*/}}
{{- define "linkly.containerSecurityContext" -}}
runAsNonRoot: true
readOnlyRootFilesystem: true
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}

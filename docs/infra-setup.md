# Infra Setup Steps

This section details some pre/post deployment steps for setting up specific apps

The `capi-infra` chart is used to configure and manage a CAPI cluster itself and any child clusters.  

Cluster API is a tool for provisioning, and operating K8s clusters. We use this tool to run K8s on Openstack. 

We utilise StackHPCs CAPI Chart to do this. See the docs [here](https://github.com/stackhpc/capi-helm-charts). The Chart `openstack-cluster` in this repo is a subchart of `capi-infra`

## Pre-deployment steps

1. **(Optional)** Add TLS Certs - for CAPI Monitoring

CAPI monitoring (which is enabled by default) requires TLS certs. 

Create a self-signed cert or get one issued. 

To create a self-signed cert:

```bash
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout privateKey.key -out certificate.crt
```

Then to create a secret from a cert - the secret name is for Prometheus, Alertmanager and Grafana is expected to be `tls-keypair` by default:

```bash
kubectl create secret tls tls-keypair --cert certificate.crt --key privateKey.key -n monitoring-system
```


2. **(Optional)** Enable sending monitoring alerts

Monitoring is enabled by default but will not send alerts out unless configured to. 
In order to turn on alerts - edit the file `clusters/<environment>/<cluster-name>infra-values.yaml` and add the following

```yaml
openstack-cluster:
  addons:
    monitoring:
      kubePrometheusStack:
        release:
          values:
            defaultRules:
              additionalRuleLabels:
                cluster: foo # name of cluster
                env: dev # dev/prod
            alertmanager:
              enabled: true
```


3. **(Optional)** Change the ingress hostnames for monitoring endpoints

```yaml
openstack-cluster:
  addons:
    monitoring:
      kubePrometheusStack:
        release:
          values:
            defaultRules: # see above
              cluster: foo # name of cluster
              env: dev # dev/prod
            alertmanager:
              enabled: true # see above
              ingress:
                hosts:
                  - <alertmanager-hostname>.nubes.stfc.ac.uk
                tls:
                  - hosts: 
                    - <alertmanager-hostname>.nubes.stfc.ac.uk
                    secretName: tls-keypair
            prometheus:
              ingress:
                hosts:
                  - <prometheus-hostname>.nubes.stfc.ac.uk
                tls:
                  - hosts: 
                    - <prometheus-hostname>.nubes.stfc.ac.uk
                    secretName: tls-keypair
            grafana:
              ingress:
                hosts:
                  - <grafana-hostname>.nubes.stfc.ac.uk
                tls:
                  - hosts: 
                    - <grafana-hostname>.nubes.stfc.ac.uk
                    secretName: tls-keypair
``` 

> [!NOTE]
> Make sure to follow post-deployment steps below for configuring sending emails


## Post-deployment

> [!WARNING]
> This will likely be deprecated for using secrets

If you have enabled monitoring. You need to manually set a few secrets that capi requires - this includes: 

1. The mail server to use to send alerts (If sending alerts)
2. Which email address to send alerts to. (If sending alerts)

Create a temporary file `/tmp/capi_patch.yaml`

```yaml
# /tmp/capi_patch.yaml
spec:
  source:
    helm:
      parameters:
      - name: >-
          openstack-cluster.addons.monitoring.kubePrometheusStack.release.values.alertmanager.config.global.smtp_smarthost
        value: <hostname>:<port>
      - name: >-
          openstack-cluster.addons.monitoring.kubePrometheusStack.release.values.alertmanager.config.receivers[1].email_configs[0].to
        value: <email-address>
```

Then you can run: 
```bash
kubectl patch -n argocd app <cluster-name> --patch-file /tmp/capi_patch.yaml --type merge
```
 
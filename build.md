## Creating the installer package

### Metrics agent
To use the latest version of monasca-agent, simply run
```
./create_metrics_agent_installer.sh
```

To use a specific version of monasca-agent, add the desired version number as an argument:
```
./create_metrics_agent_installer.sh <version_number>
```

Either way, this will generate a new executable named: `monasca-agent-<version_number>.run` .

### Log agent
To use default versions of `logstash` and `logstash_output_monasca_log_api`, simply run
```
./create_log_agent_installer.sh
```
You can add an argument to specify the `logstash` version, or two arguments to also specify the `logstash_output_monasca_log_api` version:
```
./create_log_agent_installer.sh <logstash_version> <logstash_output_monasca_log_api_version>
```
This will generate a new executable named: `log-agent-<logstash_version>_<logstash_output_monasca_log_api_version>.run` .

### Monasca-ui plugin

In order to create the monasca-ui installer, you need to run the
following command:
```
./create_monasca_ui_installer.sh <version_number>
```

In case the `<version_number>` is omitted, the newest one will be used.

## Releasing

Rename the installer packages to match the OpenStack version, e.g.:

```
metric-agent-pike.run
log-agent-pike.run
monasca-ui-pike.run
```

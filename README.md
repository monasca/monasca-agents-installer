# Monasca Agents Installer

This project allows to create a self-extracting installer for Monasca agents
([metrics agent](https://github.com/openstack/monasca-agent), log agent and, in future, events agent).
The aim of the installer is to easily install and configure agents on the target host.
This project uses [makeself](https://github.com/megastep/makeself/) for building the self-extracting archive.

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
## Running the installer

### Metrics agent
Please use the embedded help for detailed and up-to-date info:

```
./monasca-agent-<version_number>.run --help
```

To provide Keystone credentials and configure the agent using auto-detection run the following command:

```
./monasca-agent.run --target /opt/monasca/monasca-agent -- --username <username> --password <password>\
                    --project_name <project> --keystone_url <keystone_url>
```

### Log agent
Please use the embedded help for detailed and up-to-date info:
```
./log-agent-<logstash_version>_<logstash_output_monsaca_log_api_version>.run --help
```
To create an agent configuration file (agent.conf), run
```
./log-agent-<logstash_version>_<logstash_output_monasca_log_api_version>.run
```
Use the following arguments to modify the default values of the`agent.conf` file, followed by any number of input file paths:
```
./log-agent-<logstash_version>_<logstash_output_monasca_log_api_version>.run \
    --monasca_log_api_url <monasca log api url> \
    --keystone_auth_url <keystone authorisation url> \
    --project_name <project name> \
    --username <username> \
    --password <password> \
    --user_domain_name <user domain name> \
    --project_domain_name <project domain name> \
    --hostname <hostname for dimensions> \
    <input_file_path_1> <input_file_path_2> <input_file_path_n>                      
```
Additionally, you can add the `--no_service` to omit the step of automatically creating `monasca-log-agent.service` in `/etc/systemd/system/`
## TODOs

- for metrics agent:
    - create service files


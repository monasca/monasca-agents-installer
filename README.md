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
TBD


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
TBD


## TODOs

- for metrics agent:
    - create service files


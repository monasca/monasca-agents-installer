# Monasca Agents Installer

This project allows to create a self-extracting installer for Monasca agents
([metrics agent](https://github.com/openstack/monasca-agent), log agent and, in future, events agent).
The aim of the installer is to easily install and configure agents on the target host.
This project uses [makeself](https://github.com/megastep/makeself/) for building the self-extracting archive.

## Creating the installer package

### Metrics agent
Simply run
```
./create_metrics_agent_installer.sh
```

You will end up with `monasca-agent.run` executable.

### Log agent
TBD


## Running the installer

### Metrics agent
Simply run the `monasca-agent.run`:

```
./monasca-agent.run
```

This will install the agent in the current directory. You may change the installtion directory by providing the 
`--target` argument.

```
./monasca-agent.run --target /opt/monasca/monasca-agent
```

### Log agent
TBD


## TODOs

- log agent installer
- for metrics agent:
    - create installer for a specified version
    - create service files
    - run monasca-setup


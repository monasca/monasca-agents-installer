# Monasca Agents Installer

This project includes everything needed to create self-extracting installers 
for Monasca agents as well as for the monasca-ui Horizon plugin, allowing the 
user to easily install and configure agents on the target host.

The agents currently supported are the [metrics agent](https://github.com/openstack/monasca-agent) 
and the log agent. (There are plans to support an events agent in the future).

This project uses [makeself](https://github.com/megastep/makeself/) for building 
the self-extracting archive.

Jump to:

[Keystone configuration](#keystone-configuration)

[Metrics agent](#metrics-agent)

[Logs agent](#logs-agent)

[Monasca UI plugin](#monasca-ui-plugin)


## Keystone configuration

Monasca agents require appropriate Keystone configuration in order to
work properly. As every use case may be different, not all the steps may
be necessary for a particular setup.

**Setting admin credentials**

In order to perform any action in Keystone, it is required to provide
admin credentials. The easiest way of doing that is by exporting the
following environment variables:
```
export OS_USERNAME=<admin user>
export OS_PROJECT_NAME=<admin project>
export OS_PASSWORD=<admin password>
export OS_AUTH_URL=<keystone auth url>
export OS_REGION_NAME=<region name>
```

One can verify if the provided credentials are correct by running 
a simple command, like

```
openstack service list
```
If this command executes without any errors, then you are most likely all set.

**Creating a dedicated project for monitoring**

If one wishes to have a dedicated project for monitoring, then it can be
created with the following command (we assume the project name to be `monitoring`:

```
openstack project create monitoring
```


**Creating monasca roles**

Monasca requires some specific roles to run correctly. One should run
the following command to create them:

```
openstack role create monasca-user
openstack role create monasca-agent
```


**Creating agent user**

The agent user will be used by metrics and logs agent to submit data to
monasca. It can be created by executing:

```
openstack user create --project monitoring --password password monitoring-agent
```

**Assigning roles**
The monitoring agent user and the admin user both require appropriate roles.
One can assign them by executing:
```
openstack role add --project monitoring --user admin monasca-user
openstack role add --project monitoring --user admin admin
openstack role add --project monitoring --user monitoring-agent monasca-agent
```


**Defining services and endpoints**
The monasca-ui plugin requires a set of services and endpoints to be
defined in the Keystone. You may need to adjust the URLs to match your
setup:

```
openstack service create --name monasca monitoring
openstack service create --name logs logs
openstack endpoint create monasca public http://192.168.10.6:8070/v2.0 --region <Region_name>
openstack endpoint create logs public http://192.168.10.6:5607/v3.0 --region <Region_name>
```

## Metrics agent

### Creating the installer package
To use the latest version of monasca-agent, simply run
```
./create_metrics_agent_installer.sh 
```

To use a specific version of monasca-agent, add the desired version number and upper constraints file as an argument:
```
./create_metrics_agent_installer.sh -v <version_number> -u <upper_constraints_file>
```

You can find an example of an upper constraints file [here](http://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=stable/pike).

Additionally, you can add the `--install_libvirt_dependencies` to install python packages for libvirt.
Either way, this will generate a new executable named: `monasca-agent-<version_number>.run` .

### Running the installer
Please use the embedded help for detailed and up-to-date info:

```
./monasca-agent-<version_number>.run --help
```

To provide Keystone credentials and configure the agent using auto-detection run the following command:

```
./monasca-agent.run \
    --target /opt/monasca-agent -- \
    --username <username> \
    --password <password> \
    --project_name <project> \
    --user_domain_name <user_domain_name> \
    --project_domain_name <project_domain_name> \
    --keystone_url <keystone_url> \
    --monasca_statsd_port <statsd_port>
```

| Parameter             | Required | Default | Example Value   | Description |
| --------------------- | -------- | ------- | --------------- | ----------- |
| `username`            | yes      | `Unset` | `myuser`        | This is a required parameter that specifies the username needed to login to Keystone to get a token |
| `password`            | yes      | `Unset` | `mypassword`    | This is a required parameter that specifies the password needed to login to Keystone to get a token |
| `keystone_url`        | yes      | `Unset` | `http://192.168.1.5:35357/v3` | This is a required parameter that specifies the url of the keystone api for retrieving tokens. **It must be a v3 endpoint.** |
| `project_name`        | no       | `null`  | `myproject`     | Specifies the name of the Keystone project name to store the metrics under, defaults to users default project. |
| `user_domain_name`    | no       | `null`  | `default`       | User domain name for username scoping |
| `project_domain_name` | no       | `null`  | `default`       | Project domain name for keystone authentication |
| `monasca_statsd_port` | no       | `8125`  | `8126`          | Integer value for statsd daemon port number. **If default port number is used, set the other number (e.g. 8126) which is not used.** |

For more parameters, please see [Monasca Agent Documentation](https://github.com/openstack/monasca-agent/blob/master/docs/Agent.md#explanation-of-primary-monasca-setup-command-line-parameters).

This will create and run a new service file `/etc/systemd/system/monasca-agent.service` with the configuration set as per the arguments mentioned above. 

### Uninstalling Metrics agent
Stop the services: 
```
systemctl stop monasca-agent
```
Delete created files: 

*(Note: there may be files in /etc/monasca/agent/ that are related to different agents, so only remove the ones listed.)*
```
sudo rm -rf /etc/monasca/agent/supervisor.conf
sudo rm -rf /etc/monasca/agent/agent.yaml
sudo rm -rf /etc/monasca/agent/conf.d/cpu.yaml
sudo rm -rf /etc/monasca/agent/conf.d/disk.yaml
sudo rm -rf /etc/monasca/agent/conf.d/kafka_consumer.yaml 
sudo rm -rf /etc/monasca/agent/conf.d/load.yaml
sudo rm -rf /etc/monasca/agent/conf.d/memory.yaml
sudo rm -rf /etc/monasca/agent/conf.d/network.yaml
sudo rm -rf /etc/monasca/agent/conf.d/postfix.yaml
sudo rm -rf /etc/monasca/agent/conf.d/process.yaml
sudo rm -rf /etc/monasca/agent/conf.d/zk.yaml
```
Finally, delete the service related to the agent.
```
sudo rm -f /etc/systemd/system/monasca-agent.service
```
## Logs agent

### Creating the installer package
To use default versions of `logstash` and `logstash_output_monasca_log_api`, simply run
```
./create_log_agent_installer.sh
```
You can add an argument to specify the `logstash` version, or two arguments to also specify the `logstash_output_monasca_log_api` version:
```
./create_log_agent_installer.sh <logstash_version> <logstash_output_monasca_log_api_version>
```
This will generate a new executable named: `log-agent-<logstash_version>_<logstash_output_monasca_log_api_version>.run` .

### Running the installer
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
    --target /opt/monasca-log-agent -- \
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
To include all the files in a directory, use the `*` wild card (eg. `/var/log/*` ).

| Parameter             | Required | Default                        | Example Value                  | Description |
| --------------------- | -------- | ------------------------------ | ------------------------------ | ----------- |
| `monasca_log_api_url` | no       | `http://localhost:5607/v3.0`   | `http://192.168.1.6:5607/v3.0` | Monasca log api URL |
| `keystone_auth_url`   | no       | `http://localhost/identity/v3` | `http://192.168.1.5:35357/v3`  | Kyestone api URL |
| `project_name`        | no       | `mini-mon`                     | `myproject`                    | Keystone project name |
| `username`            | no       | `monasca-agent`                | `myuser`                       | Keystone user name |
| `password`            | no       | `password`                     | `mypassword`                   | Keystone password |
| `user_domain_name`    | no       | `default`                      |                                | User domain id for username scoping |
| `project_domain_name` | no       | `default`                      |                                | Project domain id for keystone authentication |
| `hostname`            | no       | `hostname`                     | `myhostname`                   | Hostname |
| `input_file_path_n`   | no       | `unset`                        | `/var/log/*`                   | Input log file path. **If this variable is not specified, default log agent configuration file is created.** |

Additionally, you can add the `--no_service` to omit the step of automatically creating `monasca-log-agent.service` in `/etc/systemd/system/`

### Uninstalling Logs agent
In the following description, 
[target_dir] is the target directory specified at the time of running log-agent-[version].run

stop the service:
```
systemctl stop monasca-log-agent
```

delete obsolete files: 
```
rm -f [target_dir]/conf
rm -f [target_dir]/monasca-log-agent
rm -f [target_dir]/logstash-[version]
rm -f /etc/systemd/system/monasca-log-agent.service
```

## Monasca-ui plugin

### Creating the installer package
In order to create the monasca-ui installer, you need to run the
following command:
```
./create_monasca_ui_installer.sh <version_number> <upper_constraints_file>
```

You can find an example of an upper constraints file [here](http://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=stable/pike).
In case the `<version_number>` is omitted, the newest one will be used.


### Running the installer
The monasca-ui plugin can be installed via the following command:
```
./monasca-ui-<version>.run --target <monasca_ui_dir>
```

This will extract the plugin with all the required dependencies.

Then it is necessary to perform a set of manual configuration steps.
First of all, you need to append the monasca-ui virtualenv libraries to
the Horizon system path. You need to find your wsgi script for Horizon 
and edit it adding:

```
sys.path.append("<monasca_ui_dir>/lib/python2.7/site-packages/") 
```

If your deployment uses Apache server for hosting the wsgi applications,
then you can look into one of the following locations (depending on your
OS) for the appropriate site configuration file:
```
/etc/apache2/sites-enabled
/etc/apache2/vhosts.d
```
Then go through the files in there and look for a line indicating the wsgi
configuration file, for example:
```
WSGIScriptAlias / /srv/www/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi
```

You may also have to append the Python system path in the `manage.py` script.

Then it is required to enable the monasca-ui plugin. Simply create
symbolic links in horizon installation pointing to the monasca-ui
installation:

```
ln -s <monasca_ui_dir>/lib/python2.7/site-packages/monitoring/enabled/_50_admin_add_monitoring_panel.py \
      <horizon_dir>/openstack_dashboard/enabled/_50_admin_add_monitoring_panel.py
ln -s <monasca_ui_dir>/lib/python2.7/site-packages/monitoring/conf/monitoring_policy.json \
      <horizon_dir>/openstack_dashboard/conf/monitoring_policy.json
```

You may also need to adjust some settings in 
`<monasca_ui_dir>/lib/python2.7/site-packages/monitoring/config/local_settings.py`
For reference please consult monasca-ui documentation.

After that, you need to restart the apache server:
```
systemctl restart apache2
```
### Uninstalling Monasca UI plugin
remove the symlinks:
```
rm <horizon_dir>/openstack_dashboard/enabled/_50_admin_add_monitoring_panel.py
rm <horizon_dir>/openstack_dashboard/conf/monitoring_policy.json
```
Remove the line with the instruction to append site-packages in the wsgi file:

Open file: `<horizon_dir>/openstack_dashboard/wsgi/django.wsgi`, delete the line: `sys.path.append("<monasca_ui_dir>/lib/python2.7/site-packages/")` and save.

Delete created files: 
```
rm -rf <installation_dir>/monasca_ui
```

Delete the installer:
```
rm -f <installation_dir>/monasca-ui-<version>.run
```

Restart the apache server
```
systemctl restart apache2
```

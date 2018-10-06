zbx2git - Zabbix Configuration Versioning Manager
================
---
zbx2git - Exports your Zabbix configuration and uses Git to store any changes made from the previous runs

A brief overview of how zbx2git works:

  - Reads your Zabbix instance configuration from zbx2git.json
  - Exports all the available configuration objects through the API ([configuration.export](https://www.zabbix.com/documentation/3.2/manual/api/reference/configuration/export)) taking advantage of parallelism
  - Individually saves the retrieved configurations locally
  - A Git Repository is created and maintained for each of the exported configurations objects


## Pre-build Docker images
- https://hub.docker.com/r/syepes/zbx2git/
- https://hub.docker.com/r/syepes/zbx2git-web/


## Build Requirements
- Ruby + Gems: parallel zabbixapi git
- Git

## CGit integration
Take a look at [cgit_integration](https://github.com/syepes/zbx2git/blob/master/docs/cgit_integration.md)

![cgit_integration](https://raw.githubusercontent.com/syepes/zbx2git/master/docs/images/cgit_example.png)

## Contribute
If you have any idea for an improvement or find a bug do not hesitate in opening an issue.

## License
zbx2git is distributed under the [Apache 2.0 License](http://www.apache.org/licenses/LICENSE-2.0)

Copyright &copy; 2016, [Sebastian YEPES F.](mailto:syepes@gmail.com)

## Used open source projects
[Ruby](http://ruby-lang.org) |
[Parallel](https://github.com/grosser/parallel) |
[Zabbixapi](https://github.com/express42/zabbixapi) |
[Git](https://git-scm.com/)


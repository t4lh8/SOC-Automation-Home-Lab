# SOC Automation Home Lab

This project focuses on building a hands-on SOC environment for security monitoring, threat detection, and incident response automation.

## Architecture

The lab architecture was planned before the implementation phase to show how the different components communicate with each other.

The environment includes a Windows 10 endpoint running the Wazuh Agent, a Wazuh Manager for event collection and alerting, Shuffle for automation, and TheHive for case management.

The architecture and workflow diagrams were created using draw.io.

![SOC Automation Architecture](images/soc-architecture.png)

## Workflow

The workflow below shows the planned event flow through the lab, from event collection to alerting, enrichment, case management, and response actions.

![SOC Automation Workflow](images/soc-workflow.png)

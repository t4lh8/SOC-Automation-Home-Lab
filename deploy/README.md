# Automated Deployment (Infrastructure as Code)

This turns the manual build guide into a near one-command deploy. Two layers:

1. **Terraform** ([`terraform/`](terraform/)) — provisions the cloud VM and a locked-down firewall.
2. **`setup.sh`** — on that VM, installs Docker and brings up Wazuh + Shuffle + TheHive.

> The lab server stack needs **~16 GB RAM**, so it runs on a cloud VM, not a laptop.
> The "spin up → test → destroy" pattern below keeps the cost to a few dollars.

## Resource sizing & cost

| | Recommended | Why |
|---|---|---|
| Droplet | `s-4vcpu-16gb` (DigitalOcean) | Wazuh indexer + TheHive/Cassandra + Shuffle are memory-hungry |
| Cost | ~$0.12/hour (~$3 for an afternoon of testing) | Destroyed with `terraform destroy` when done |

Tight on budget? Run only part of the stack: `sudo ./setup.sh wazuh` on an 8 GB droplet.

## Option A — fully automated (Terraform)

Prerequisites: a DigitalOcean account, an SSH key uploaded to it, and
[Terraform](https://developer.hashicorp.com/terraform/downloads) installed locally.

```bash
cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your token, SSH fingerprint, IP
terraform init
terraform apply          # creates the VM + firewall, installs Docker (cloud-init)
```

Terraform prints the server IP and next steps. Then:

```bash
ssh root@<server-ip>
cd /opt/SOC-Automation-Home-Lab/deploy
cp .env.example .env
sudo ./setup.sh          # brings up Wazuh + Shuffle + TheHive
```

When you're finished testing:

```bash
terraform destroy        # stops all charges
```

## Option B — manual VM, automated stack

Already have an Ubuntu 22.04 box (any cloud, or a local VM with enough RAM)?
Skip Terraform and just run the stack deployer:

```bash
git clone https://github.com/t4lh8/SOC-Automation-Home-Lab.git
cd SOC-Automation-Home-Lab/deploy
cp .env.example .env
sudo ./setup.sh                 # all three components
# or one at a time:  sudo ./setup.sh wazuh
```

## What setup.sh does

- Installs Docker Engine + Compose plugin (if missing)
- Tunes `vm.max_map_count` for the search engines
- Deploys **Wazuh** single-node from the official `wazuh-docker` (pinned version)
- Deploys **Shuffle** from the official repo
- Deploys **TheHive + Cassandra** from [`thehive/docker-compose.yml`](thehive/docker-compose.yml)
- Prints the dashboard URLs and the remaining manual steps (load rules, build workflow)

## After the stack is up

The config in this repo (rules, agent config, workflow) still gets applied on top —
follow the numbered guides in [`../docs/`](../docs/), starting at
[02-wazuh-manager-setup.md](../docs/02-wazuh-manager-setup.md).

## Security notes

- The firewall limits every dashboard to **your IP only**; only the Wazuh agent ports
  are open, and only to your endpoint's IP.
- Change every default password on first login (Wazuh, Shuffle, TheHive).
- `.env`, Terraform state and `*.tfvars` hold secrets and are git-ignored.

GCP project is created -> default network provides each region with an auto subnet network.

## Networking in GCP

You can create up to four additional networks per project

Additional networks can be auto subnet networks, custom subnet networks, or legacy networks

Each instance created within a subnetwork is assigned an IPv4 address from that subnetwork range


## Firewalls, Ingresses and Egresses

Each network has a default firewall that blocks all inbound traffic to instances

To allow traffic you must create "allow" rules for the firewall (ingress)

Default firewall allows for outgoing traffic; create "deny" rules to restrict egress

The more restrictive configuration the more predictable the network requests will be

Auto-created ingress firewall rules are as follows:

- `default-allow-internal` Allows network connections of any protocol and port between instances on the network
- `default-allow-ssh` Allows SSH connections from any source to any instance on the network over TCP port 22
- `default-allow-rdp` Allows RDP connections from any source to any instance on the network over TCP port 3389
- `default-allow-icmp` Allows ICMP traffic from any source to any instance on the network

GCP: Products -> VPC networks -> firewall rules

### Network Routes

All networks have routes to the internet (default route) and to the IP ranges in the network. The route are automatically genereated and will look different for each project

GCP: Products -> VPC network -> Routes

## Custom Networks

### Creating a new network with custom subnet ranges

First create a custom subnet network and create the subnetworks that you want within a region
> You do not have to specify subnetworks for all regions, but you cannot create instances in regions that have no subnetwork defined

When you create a new subnetwork, its name must be unique in that project for that region across networks. The same name can appear twice in a project as long as each one is in a different region.

Products -> Networking -> VPC Network

- Click *Create VPC Network* and name it "something-custom-network"
- On the *Custom* tab create:
  - Subnet name: subnet-us-central
  - Region: `us-central1
  - IP address range 10.0.0.0/16`
- Now click *+ Add Subnetwork* and add two more subnets in their respective regions:
  - `subnet-europe-west`, 10.1.0.0/16
  - `subnet-asia-east`, 10.2.0.0/16

Code example:

```bash
$ gcloud compute networks create taw-custom-network --mode custom

# Output
NAME                MODE    IPV4_RANGE  GATEWAY_IPV4
taw-custom-network  custom

Instances on this network will not be reachable until firewall rules
are created. As an example, you can allow all internal traffic between
instances as well as SSH, RDP, and ICMP by running:

$ gcloud compute firewall-rules create <FIREWALL_NAME> --network taw-custom-network --allow tcp,udp,icmp --source-ranges <IP_RANGE>
$ gcloud compute firewall-rules create <FIREWALL_NAME> --network taw-custom-network --allow tcp:22,tcp:3389,icmp

# Create the three custom subnets
$ gcloud compute networks subnets create subnet-us-central \
   --network taw-custom-network \
   --region us-central1 \
   --range 10.0.0.0/24

# Output
Created [https://www.googleapis.com/compute/v1/projects/cloud-network-module-101/regions/us-central1/subnetworks/subnet-us-central].
NAME               REGION       NETWORK             RANGE
subnet-us-central  us-central1  taw-custom-network  10.0.0.0/24

$ gcloud compute networks subnets create subnet-europe-west \
   --network taw-custom-network \
   --region europe-west1 \
   --range 10.1.0.0/24

# Output
Created [https://www.googleapis.com/compute/v1/projects/cloud-network-module-101/regions/europe-west1/subnetworks/subnet-europe-west].
NAME                REGION        NETWORK             RANGE
subnet-europe-west  europe-west1  taw-custom-network  10.1.0.0/24

$ gcloud compute networks subnets create subnet-asia-east \
   --network taw-custom-network \
   --region asia-east1 \
   --range 10.2.0.0/24

# Output
Created [https://www.googleapis.com/compute/v1/projects/cloud-network-module-101/regions/asia-east1/subnetworks/subnet-asia-east1].
NAME                REGION        NETWORK             RANGE
subnet-asia-east    asian-east1   taw-custom-network  10.2.0.0/24
```

Now, the network inherently has routes to the internet and to any instances you might create. But, it has no firewall rules allowing access to instances, even from other instances. You must create firewall rules to allow access.

### Adding Firewall Rules

```bash
$ gcloud compute firewall-rules create nw101-allow-http \
--allow tcp:80 --network taw-custom-network --source-ranges 0.0.0.0/0 \
--target-tags http

# Output
Created [https://www.googleapis.com/compute/v1/projects/cloud-network-module-101/global/firewalls/nw101-allow-http].
NAME              NETWORK             SRC_RANGES  RULES   SRC_TAGS  TARGET_TAGS
nw101-allow-http  taw-custom-network  0.0.0.0/0   tcp:80            http
```

*ICMP*

```bash
$ gcloud compute firewall-rules create "nw101-allow-icmp" --allow icmp --network "taw-custom-network"
```

*SSH*

```bash
$ gcloud compute firewall-rules create "nw101-allow-ssh" --allow tcp:22 --network "taw-custom-network" --target-tags "ssh"
```

*RDP*

```bash
$ gcloud compute firewall-rules create "nw101-allow-rdp" --allow tcp:3389 --network "taw-custom-network"
```

Regarding routes:

GCP Networking uses Routes to direct packets between subnetworks and to the internet. When a subnetwork is created, routes are automatically created in each region to all packets to route between subnetworks, and cannot be modified.

Additional routes can be created to send traffic to an instance, a VPN gateway, or default internet gateway. These Routes can be modified to tailer the desired network architecture.

### Creating compute instances in the subnets

```bash
$ gcloud compute instances create us-test-01 \
--subnet subnet-us-central \
--zone us-central1-a \
--tags ssh,http

# Output
Created [https://www.googleapis.com/compute/v1/projects/cloud-network-module-101/zones/us-central1-a/instances/us-test-01].
NAME        ZONE           MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
us-test-01  us-central1-a  n1-standard-1               10.0.0.2     104.198.230.22  RUNNING

$ gcloud compute instances create europe-test-01 \
--subnet subnet-europe-west \
--zone europe-west1-b \
--tags ssh,http

# Output ...
$ gcloud compute instances create asia-test-01 \
--subnet subnet-asia-east \
--zone asia-east1-a \
--tags ssh,http

# Output ...
```

SSH into `us-test-01` and use an ICMP echo against the other instances:

```bash
ping -c 3 <europe-test-01-external-ip-address>

# Output
PING 35.187.149.67 (35.187.149.67) 56(84) bytes of data.
64 bytes from 35.187.149.67: icmp_seq=1 ttl=76 time=152 ms
64 bytes from 35.187.149.67: icmp_seq=2 ttl=76 time=152 ms
64 bytes from 35.187.149.67: icmp_seq=3 ttl=76 time=152 ms
```

### Internal DNS

Each instance has a metadata server that also acts as a DNS resolver for that instance. DNS lookups are performed for instance names. The metadata server itself stores all DNS information for the local network and queries Google's public DNS servers for any address outside of the local network.

An internal fully qualified domain name (FQDN) for an instance looks like this:

```
hostName.c.[PROJECT_ID].internal
```

You can always connect from one instance to another using this FQDN. If you want to connect to an instance using, for example, just hostName, you need information from the internal DNS resolver that is provided as part of Compute Engine.

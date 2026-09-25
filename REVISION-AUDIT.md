# Audit orchestrator — la grille officielle, question par question

Ce fichier suit la [grille d'audit officielle](https://github.com/01-edu/public/blob/master/subjects/devops/orchestrator/audit/README.md)
dans l'ordre exact : **33 points à cocher et 12 questions orales, soit 45
entrées**. Pour chacune : la question en français, sa formulation exacte dans la
grille (en italique), la réponse à donner, puis la commande qui la prouve et la
sortie obtenue sur le cluster réellement construit depuis ce dépôt (captures du
22 au 25 septembre 2026 ; seules les durées `AGE` et les suffixes aléatoires
des pods changent d'un jour à l'autre).

Les explications longues sont dans le [README](README.md) ; les renvois `§` y
pointent.

> **Avant l'audit, 5 minutes :**
>
> ```bash
> cd ~/dev/"Master Bac +5"/orchestrator
> ./orchestrator.sh start        # ~1 min, affiche « cluster started »
> ./orchestrator.sh test         # 14 vérifications, doit finir par « All 14 checks passed »
> ```
>
> Passerelle : `http://192.168.56.110:3000` (ou `192.168.56.111:3000`). Garder
> ce fichier et le README ouverts dans VS Code. Si l'auditeur préfère Postman à
> `curl` : méthode `POST`, onglet *Body* → *raw* → *JSON*, et l'en-tête
> `Content-Type: application/json` est ajouté automatiquement.

## Sommaire

| Partie de la grille | Entrées |
|---|---|
| [A. Général — contenu du dépôt](#a-général--contenu-du-dépôt) | 1 à 2 |
| [B. Questions : orchestration, Kubernetes, K3s](#b-questions--orchestration-kubernetes-k3s) | 3 à 6 |
| [C. Documentation et Docker Hub](#c-documentation-et-docker-hub) | 7 à 8 |
| [D. Le cluster](#d-le-cluster) | 9 à 12 |
| [E. L'infrastructure](#e-linfrastructure) | 13 à 15 |
| [F. Les manifests](#f-les-manifests) | 16 à 17 |
| [G. Questions : IaC et manifests](#g-questions--iac-et-manifests) | 18 à 21 |
| [H. Les secrets](#h-les-secrets) | 22 |
| [I. Les ressources déployées](#i-les-ressources-déployées) | 23 à 24 |
| [J. Questions : StatefulSet, Deployment, scaling, load balancer](#j-questions--statefulset-deployment-scaling-load-balancer) | 25 à 31 |
| [K. API inventaire](#k-api-inventaire) | 32 à 33 |
| [L. API facturation](#l-api-facturation) | 34 à 36 |
| [M. Base de données de facturation](#m-base-de-données-de-facturation) | 37 à 39 |
| [N. Résilience de la file de messages](#n-résilience-de-la-file-de-messages) | 40 à 41 |
| [O. Les composants de Kubernetes](#o-les-composants-de-kubernetes) | 42 |
| [P. Bonus](#p-bonus) | 43 à 45 |

---

## A. Général — contenu du dépôt

### 1. Tous les fichiers demandés sont-ils présents ?

*Are all the required files present?*

**Réponse :** Oui. Le dépôt contient le `README.md`, le script `orchestrator.sh`,
le `Vagrantfile`, les manifests dans `Manifests/`, les scripts dans `Scripts/`
et les Dockerfiles avec leur code dans `Dockerfiles/`. Les seuls fichiers
volontairement absents sont les Secrets générés (`Manifests/secrets/*.yaml`),
parce qu'ils contiennent les mots de passe ; leurs modèles `*.yaml.example`
sont versionnés et `./orchestrator.sh create` génère les vrais fichiers.

**Preuve :**

```console
$ ls
Dockerfiles  Manifests  orchestrator.sh  README.md  REVISION-AUDIT.md  Scripts  Vagrantfile
$ ls Manifests Manifests/secrets Scripts
Manifests:
api-gateway.yaml  billing-database.yaml  inventory-app.yaml       rabbitmq.yaml  storage.yaml
billing-app.yaml  bonus                  inventory-database.yaml  secrets

Manifests/secrets:
billing-db-secret.yaml          inventory-db-secret.yaml          rabbitmq-secret.yaml
billing-db-secret.yaml.example  inventory-db-secret.yaml.example  rabbitmq-secret.yaml.example

Scripts:
generate-secrets.sh  k3s-agent.sh  k3s-master.sh  load-test.sh  push-images.sh  test-api.sh
$ git check-ignore -v Manifests/secrets/billing-db-secret.yaml
.gitignore:6:Manifests/secrets/*.yaml	Manifests/secrets/billing-db-secret.yaml
```

### 2. La structure suit-elle celle du sujet ? Sinon, est-elle justifiée ?

*Does the project as a structure similar to the one below? If not, can the student provide a justification for the chosen project structure?*

**Réponse :** Oui, c'est la structure du sujet : `Manifests/`, `Scripts/`,
`Dockerfiles/`, `Vagrantfile`. Deux choix à justifier :

- `orchestrator.sh` est **à la racine** et non dans `Scripts/`, parce que c'est
  le point d'entrée que le sujet et la grille appellent `./orchestrator.sh
  create`. `Scripts/` contient les scripts qu'il appelle.
- `Dockerfiles/` contient **le code source** en plus des Dockerfiles, parce
  qu'une image se construit à partir d'un contexte complet (code,
  `package-lock.json`, scripts d'entrée, schémas SQL).

**Preuve :**

```console
$ find . -maxdepth 2 -not -path './.git*' -not -path './.vagrant*' -not -path './Dockerfiles/*' | LC_ALL=C sort
.
./.hadolint.yaml
./Dockerfiles
./Manifests
./Manifests/api-gateway.yaml
./Manifests/billing-app.yaml
./Manifests/billing-database.yaml
./Manifests/bonus
./Manifests/inventory-app.yaml
./Manifests/inventory-database.yaml
./Manifests/rabbitmq.yaml
./Manifests/secrets
./Manifests/storage.yaml
./README.md
./REVISION-AUDIT.md
./Scripts
./Scripts/generate-secrets.sh
./Scripts/k3s-agent.sh
./Scripts/k3s-master.sh
./Scripts/load-test.sh
./Scripts/push-images.sh
./Scripts/test-api.sh
./Vagrantfile
./orchestrator.sh
$ ls Dockerfiles
api-gateway  billing-app  billing-database  inventory-app  inventory-database  rabbitmq-server
```

Détail : README [§16](README.md#16-arborescence-du-dépôt).

---

## B. Questions : orchestration, Kubernetes, K3s

Ces trois questions valident un seul point de la grille (entrée 6). Elles
tombent à tous les audits : les réponses s'enchaînent, apprendre les trois
ensemble.

### 3. Qu'est-ce que l'orchestration de conteneurs, et quels sont ses avantages ?

*What is container orchestration, and what are its benefits?*

**Réponse à dire :** L'orchestration, c'est **l'automatisation du déploiement
et de la gestion de conteneurs sur un ensemble de machines**. Avec Docker
Compose, j'avais six conteneurs sur une seule machine ; si elle s'éteint, tout
s'arrête. Avec un orchestrateur, je **déclare l'état voulu** — quelles images,
combien de copies, quelles ressources — et il le met en place sur le cluster,
puis le **maintient** tout seul.

Les cinq avantages, à réciter (**PARMU**) :

| | Avantage | Dans mon cluster |
|---|---|---|
| **P** | **Placement** automatique | le scheduler choisit master ou agent pour chaque pod |
| **A** | **Auto-réparation** | un pod qui meurt est relancé ; un nœud qui tombe voit ses pods recréés ailleurs |
| **R** | **Répartition de charge** | le Service distribue les requêtes entre les copies |
| **M** | **Mise à l'échelle** | le HPA passe la passerelle de 1 à 3 pods sous la charge |
| **U** | **Updates** progressives | remplacement des pods un par un, retour arrière possible |

**Démonstration si l'auditeur veut voir l'auto-réparation :**

```console
$ kubectl delete pod -l app=api-gateway
pod "api-gateway-7ff5cbccf9-h6nsl" deleted from default namespace
$ kubectl get pods -l app=api-gateway
NAME                           READY   STATUS    RESTARTS   AGE
api-gateway-7ff5cbccf9-8n4r7   1/1     Running   0          9s
```

Le pod supprimé est remplacé en quelques secondes, sans intervention.

### 4. Qu'est-ce que Kubernetes, et quel est son rôle principal ?

*What is Kubernetes, and what is its main role?*

**Réponse à dire :** Kubernetes (K8s) est **l'orchestrateur de conteneurs
open source de référence**, créé par Google à partir de son outil interne Borg,
et maintenu aujourd'hui par la CNCF. Son rôle principal : **faire tourner des
applications conteneurisées sur un cluster de machines en maintenant en
permanence l'état que j'ai déclaré**. Je décris des objets dans des fichiers
YAML (Deployment, Service, Secret…), et ses contrôleurs, dans une boucle de
réconciliation, comparent sans arrêt l'état réel à l'état souhaité et corrigent
tout écart — comme un thermostat.

**Preuve :** la colonne `READY` compare l'état réel (à gauche) à l'état désiré
(à droite).

```console
$ kubectl get deployments,statefulsets
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/api-gateway     1/1     1            1           2d21h
deployment.apps/inventory-app   1/1     1            1           2d21h

NAME                            READY   AGE
statefulset.apps/billing-app    1/1     2d21h
statefulset.apps/billing-db     1/1     2d21h
statefulset.apps/inventory-db   1/1     2d21h
statefulset.apps/rabbitmq       1/1     2d21h
```

### 5. Qu'est-ce que K3s, et quel est son rôle principal ?

*What is K3s, and what is its main role?*

**Réponse à dire :** K3s est une **distribution Kubernetes légère et certifiée
par la CNCF**, créée par Rancher (SUSE). C'est un vrai Kubernetes — mêmes API,
même `kubectl`, mêmes manifests — mais livré en **un seul binaire** de moins de
100 Mo, qui démarre avec peu de mémoire. Il embarque tout le nécessaire :
containerd pour exécuter les conteneurs, flannel pour le réseau, CoreDNS,
metrics-server, ServiceLB pour les Services `LoadBalancer`, et remplace etcd
par SQLite sur un serveur unique. Son rôle : **fournir un cluster complet sur
des machines modestes** (edge, IoT, laboratoire) — ici deux VM de 2 Go.

Moyen mnémotechnique : « Kubernetes » s'écrit K8s (K + 8 lettres + s). Une
version deux fois plus petite, c'est K3s.

**Preuve :**

```console
$ kubectl get nodes
NAME     STATUS   ROLES           AGE     VERSION
agent    Ready    <none>          2d21h   v1.36.4+k3s1
master   Ready    control-plane   2d22h   v1.36.4+k3s1
$ vagrant ssh master -c 'ls -lh /usr/local/bin/k3s; sudo ls /var/lib/rancher/k3s/server/db/'
-rwxr-xr-x 1 root root 76M Sep 22 09:20 /usr/local/bin/k3s
state.db
state.db-shm
state.db-wal
```

Un seul binaire de 76 Mo, et une base SQLite (`state.db`) à la place d'etcd.

### 6. L'étudiant a-t-il répondu correctement ?

*Did the student reply correctly to the questions?*

Point coché si les trois réponses précédentes sont données. En une phrase
chacune : **orchestration** = gérer automatiquement des conteneurs sur plusieurs
machines ; **Kubernetes** = l'orchestrateur de référence, qui maintient l'état
déclaré ; **K3s** = Kubernetes allégé en un seul binaire, pour les petites
machines.

---

## C. Documentation et Docker Hub

### 7. Le README contient-il toute la documentation ?

*Did the README.md file contains all the required information about the solution (prerequisites, configuration, setup, usage, ...)?*

**Réponse :** Oui : prérequis (§1), configuration (§2), installation (§3),
utilisation (§4), API (§5), scénario d'audit avec les sorties capturées (§6),
chaque manifest expliqué (§7), secrets, stockage NFS, autoscaling, cluster
Vagrant/K3s, images et Docker Hub, sécurité, bonus, dépannage, réponses aux
questions d'audit (§17) et composants de Kubernetes (§18).

**Preuve :** le [sommaire du README](README.md#sommaire).

```console
$ grep -c '^## ' README.md
22
```

### 8. Les images des manifests viennent-elles de mon compte Docker Hub ?

*Are the docker images used in the YAML manifest uploaded from the student's Docker Hub account?*

**Réponse :** Oui. Les six images sont sur `docker.io/clecart`, en tag fixe
`1.0.0`, publiques, construites depuis mes Dockerfiles et poussées par
`./orchestrator.sh push`. Le cluster les tire de là : j'ai vérifié en
supprimant les images des nœuds et en redéployant, et l'identifiant d'image de
chaque pod porte le nom du registre et du compte.

**Preuve :**

```console
$ grep -h 'image:' Manifests/*.yaml
          image: clecart/api-gateway:1.0.0
          image: clecart/billing-app:1.0.0
          image: clecart/billing-database:1.0.0
          image: clecart/inventory-app:1.0.0
          image: clecart/inventory-database:1.0.0
          image: clecart/rabbitmq-server:1.0.0
$ kubectl get pods -o custom-columns='POD:.metadata.name,IMAGE:.status.containerStatuses[0].imageID'
POD                              IMAGE
api-gateway-7ff5cbccf9-h6nsl     docker.io/clecart/api-gateway@sha256:aebebbc050a759f9f81bb4ed172fb44c2647700a90efa7640332757853b35aa7
billing-app-0                    docker.io/clecart/billing-app@sha256:61f4bc8fac8e9900fb640e387154184eb08fd043f95870498a2920b0557984e0
billing-db-0                     docker.io/clecart/billing-database@sha256:70380b5602ef8c18214c00efda400ee72d751f7211e153b4e17ed8b5161def6d
inventory-app-7d56f997b8-lmhlr   docker.io/clecart/inventory-app@sha256:175e33726852eaacabccac0c9e827939ecd6267d2d4a54ffceff1d755cb9488d
inventory-db-0                   docker.io/clecart/inventory-database@sha256:f5ea338d108ddbea01113d49ac57896debea07b14273179c8c4a6b460764babe
rabbitmq-0                       docker.io/clecart/rabbitmq-server@sha256:dbff498131905b9c137a27e2719839732e5c34c07f7f2139a3a8f3bd7c18989a
```

Et sur le site : <https://hub.docker.com/u/clecart> — six dépôts publics, tag
`1.0.0`. Les empreintes `sha256` ci-dessus sont celles affichées par Docker Hub.

---

## D. Le cluster

### 9. kubectl est-il installé et configuré sur ma machine ?

*Is kubectl installed and configured in the learner's machine?*

**Réponse :** Oui. `kubectl` v1.36.4 est installé sur ma machine (hors des
VM), et `orchestrator.sh` a fusionné les identifiants d'administration de K3s
dans `~/.kube/config` sous le contexte `orchestrator`, en remplaçant l'adresse
`127.0.0.1` par celle du master. Toutes les commandes du script passent
`--context orchestrator` : elles ne touchent jamais un autre cluster.

**Preuve :**

```console
$ which kubectl
/home/zone01student/.local/bin/kubectl
$ kubectl version
Client Version: v1.36.4
Kustomize Version: v5.8.1
Server Version: v1.36.4+k3s1
$ kubectl config current-context
orchestrator
$ kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
https://192.168.56.110:6443
```

### 10. Le cluster a-t-il été créé par un Vagrantfile ?

*Was the cluster created by a Vagrantfile?*

**Réponse :** Oui. Le `Vagrantfile` définit les deux VM `master` et `agent`
(box `bento/ubuntu-24.04`, VirtualBox, 2 vCPU et 2 Go chacune, IP fixes sur
un réseau privé) et lance leur provisioning : `Scripts/k3s-master.sh`
(serveur NFS + K3s server) et `Scripts/k3s-agent.sh` (client NFS + K3s agent).
Le jeton de jonction est généré au premier `vagrant up` dans `.vagrant/`,
ignoré par Git.

**Preuve :**

```console
$ vagrant status
Current machine states:

master                    running (virtualbox)
agent                     running (virtualbox)
$ VBoxManage list runningvms
"orchestrator-master" {9e8ded94-0b45-478f-a1d4-9214daa3112f}
"orchestrator-agent" {3273344c-716b-4f27-bc85-17e86aafd193}
$ grep -nE '^(BOX|K3S_VERSION|MASTER|AGENT) ' Vagrantfile
15:BOX         = "bento/ubuntu-24.04"
17:K3S_VERSION = "v1.36.4+k3s1"
19:MASTER = { name: "master", ip: "192.168.56.110", cpus: 2, memory: 2048 }
20:AGENT  = { name: "agent",  ip: "192.168.56.111", cpus: 2, memory: 2048 }
```

### 11. Le cluster a-t-il deux nœuds, master et agent ?

*Does the cluster contain two nodes (master and agent)?*

**Réponse :** Oui : `master`, qui porte le plan de contrôle (rôle
`control-plane`) et exécute aussi des pods, et `agent`, qui n'exécute que des
pods. L'agent n'a pas de rôle affiché (`<none>`), exactement comme dans
l'exemple de la grille.

**Preuve :**

```console
$ kubectl get nodes -A -o wide
NAME     STATUS   ROLES           AGE     VERSION        INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION             CONTAINER-RUNTIME
agent    Ready    <none>          2d21h   v1.36.4+k3s1   192.168.56.111   <none>        Ubuntu 24.04.3 LTS   6.8.0-86-generic (amd64)   containerd://2.3.4-k3s1.36
master   Ready    control-plane   2d22h   v1.36.4+k3s1   192.168.56.110   <none>        Ubuntu 24.04.3 LTS   6.8.0-86-generic (amd64)   containerd://2.3.4-k3s1.36
```

### 12. Les nœuds sont-ils connectés et prêts ?

*Are the nodes connected and ready for usage?*

**Réponse :** Oui, les deux sont `Ready`, et des pods tournent sur chacun. Les
pods de deux nœuds différents se parlent : la passerelle sur un nœud atteint
l'inventaire ou RabbitMQ sur l'autre par le réseau flannel.

**Preuve :**

```console
$ kubectl get nodes
NAME     STATUS   ROLES           AGE     VERSION
agent    Ready    <none>          2d21h   v1.36.4+k3s1
master   Ready    control-plane   2d22h   v1.36.4+k3s1
$ kubectl get pods -o wide --no-headers | awk '{print $1, $3, $7}'
api-gateway-7ff5cbccf9-h6nsl Running agent
billing-app-0 Running agent
billing-db-0 Running master
inventory-app-7d56f997b8-lmhlr Running master
inventory-db-0 Running agent
rabbitmq-0 Running master
```

---

## E. L'infrastructure

### 13. `orchestrator.sh` crée-t-il et gère-t-il l'infrastructure ?

*Did the student provide an `orchestrator.sh` script that runs and creates and manages the infrastructure?*

**Réponse :** Oui. `create` crée les VM, installe K3s, configure kubectl,
génère les secrets et déploie tout, puis affiche `cluster created` ; `start`
et `stop` affichent `cluster started` et `cluster stopped`, comme le sujet le
demande. S'y ajoutent `destroy`, `status`, `deploy`, `undeploy`, `push`,
`test`, `load` et `bonus`.

**Preuve :**

```console
$ ./orchestrator.sh help
orchestrator.sh - creates, starts, stops and manages the K3s cluster (two
Vagrant VMs) and the microservices deployed on it.

Usage: ./orchestrator.sh <command> [options]

Cluster:
  create     create the VMs, install K3s, configure kubectl, deploy the stack
  start      boot the VMs of an existing cluster and wait for the stack
  stop       shut the VMs down (the data is kept)
  destroy    delete the VMs and the "orchestrator" kubectl context
  status     show the VMs, the nodes and every deployed resource
[...]
$ ./orchestrator.sh create
[...]
gateway: http://192.168.56.110:3000
cluster created
$ ./orchestrator.sh stop
==> cordoning the nodes (no pod is rescheduled during the shutdown)
==> shutting down the VMs
==> agent: Attempting graceful shutdown of VM...
==> master: Attempting graceful shutdown of VM...
cluster stopped
$ ./orchestrator.sh start
[...]
cluster started
```

Durées mesurées : `create` de zéro ≈ 4 min (box déjà téléchargée), `stop`
≈ 25 s, `start` ≈ 1 min.

### 14. L'architecture est-elle respectée ?

*Did the student respect the architecture?*

**Réponse :** Oui, composant par composant du schéma du sujet :

| Schéma du sujet | Dans le cluster |
|---|---|
| Client → `api-gateway` (port 3000) | Service `LoadBalancer` sur 3000, Deployment `api-gateway` |
| `api-gateway` → `inventory-app` (HTTP, 8080) | `INVENTORY_APP_URL=http://inventory-app:8080`, Service ClusterIP |
| `inventory-app` → `inventory-database` (5432) | `DB_HOST=inventory-db`, StatefulSet + Service headless |
| `api-gateway` → RabbitMQ → `billing-app` | `RABBITMQ_HOST=rabbitmq`, file `billing_queue`, StatefulSet `billing-app` |
| `billing-app` → `billing-database` (5432) | `DB_HOST=billing-db`, StatefulSet + Service headless |
| Secrets | `inventory-db-secret`, `billing-db-secret`, `rabbitmq-secret` |
| Volumes | 3 PersistentVolumes NFS |
| Docker Hub → manifests | `image: clecart/<nom>:1.0.0` |
| kubectl, Vagrant, Vagrantfile | `orchestrator.sh`, contexte `orchestrator`, `Vagrantfile` |

**Preuve :** `kubectl get all` (entrée 23) et le schéma du README
[§0.2](README.md#02-architecture-applicative).

### 15. L'infrastructure a-t-elle démarré correctement ?

*Did the infrastructure start correctly?*

**Réponse :** Oui : six pods `1/1 Running`, trois volumes `Bound`, passerelle
qui répond `200` sur `/health`.

**Preuve :**

```console
$ kubectl get pods
NAME                             READY   STATUS    RESTARTS   AGE
api-gateway-7ff5cbccf9-h6nsl     1/1     Running   0          42h
billing-app-0                    1/1     Running   0          42h
billing-db-0                     1/1     Running   0          42h
inventory-app-7d56f997b8-lmhlr   1/1     Running   0          42h
inventory-db-0                   1/1     Running   0          42h
rabbitmq-0                       1/1     Running   0          42h
$ kubectl get pvc
NAME                  STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
data-billing-db-0     Bound    billing-db-pv     1Gi        RWO            nfs            <unset>                 2d21h
data-inventory-db-0   Bound    inventory-db-pv   1Gi        RWO            nfs            <unset>                 2d21h
data-rabbitmq-0       Bound    rabbitmq-pv       1Gi        RWO            nfs            <unset>                 2d21h
$ curl -s -w '\n%{http_code}\n' http://192.168.56.110:3000/health
{"status":"ok","rabbitmq":"connected"}
200
```

---

## F. Les manifests

### 16. Y a-t-il un manifest YAML par service ?

*Is there a YAML Manifest for each service?*

**Réponse :** Oui, un fichier par service du schéma : `api-gateway.yaml`,
`inventory-app.yaml`, `inventory-database.yaml`, `billing-app.yaml`,
`billing-database.yaml`, `rabbitmq.yaml`. Plus `storage.yaml` (classe de
stockage et volumes), les Secrets dans `secrets/`, et les tableaux de bord
bonus dans `bonus/`.

**Preuve :**

```console
$ ls Manifests/*.yaml
Manifests/api-gateway.yaml   Manifests/billing-database.yaml   Manifests/inventory-database.yaml   Manifests/storage.yaml
Manifests/billing-app.yaml   Manifests/inventory-app.yaml      Manifests/rabbitmq.yaml
$ grep -h '^kind:' Manifests/*.yaml | sort | uniq -c
      1 kind: ConfigMap
      2 kind: Deployment
      2 kind: HorizontalPodAutoscaler
      3 kind: PersistentVolume
      6 kind: Service
      4 kind: StatefulSet
      1 kind: StorageClass
```

### 17. Aucun identifiant hors des manifests de Secrets ?

*Are credentials not existing in the YAML manifests, except the secret manifests?*

**Réponse :** Aucun. Les manifests d'application ne contiennent que des
références `secretKeyRef` vers les trois Secrets. Et je vais plus loin que le
sujet : même les manifests de Secrets ne sont pas versionnés ; le dépôt ne
contient que des modèles avec des valeurs `CHANGE_ME_*`, et
`Scripts/generate-secrets.sh` fabrique les vrais fichiers avec des mots de
passe aléatoires de 128 bits.

**Preuve :**

```console
$ grep -rnE 'password|passwd|secret' Manifests/*.yaml | grep -v -E 'secretKeyRef|name: .*-secret|key: password'
$
$ grep -hE '^\s*password:' Manifests/secrets/*.yaml.example
  password: CHANGE_ME_BILLING_DB_PASSWORD
  password: CHANGE_ME_RABBITMQ_PASSWORD
  password: CHANGE_ME_INVENTORY_DB_PASSWORD
$ git ls-files Manifests/secrets
Manifests/secrets/billing-db-secret.yaml.example
Manifests/secrets/inventory-db-secret.yaml.example
Manifests/secrets/rabbitmq-secret.yaml.example
```

Le premier `grep` ne renvoie rien ; Git ne connaît que les modèles.

---

## G. Questions : IaC et manifests

Ces trois questions valident un seul point de la grille (entrée 21).

### 18. Qu'est-ce que l'infrastructure as code, et quels sont ses avantages ?

*What is infrastructure as code and what are the advantages of it?*

**Réponse à dire :** L'infrastructure as code, c'est **décrire l'infrastructure
dans des fichiers texte versionnés** — machines, réseau, logiciels,
déploiements — au lieu de la configurer à la main. Ici, tout le projet en est :
le `Vagrantfile` décrit les VM, les scripts de provisioning installent K3s et
NFS, les manifests décrivent l'application.

Les avantages :
- **reproductible** : `./orchestrator.sh create` recrée la même infrastructure
  sur n'importe quelle machine ;
- **versionné** : historique, revue, retour arrière avec Git ;
- **documenté par nature** : le fichier est la documentation ;
- **automatisable** : intégration continue, déploiement continu ;
- **sans dérive ni erreur manuelle** : deux environnements créés depuis les
  mêmes fichiers sont identiques, et on peut détruire et recréer sans crainte.

**Preuve :** j'ai détruit et recréé le cluster de zéro pendant le
développement : `./orchestrator.sh destroy` puis `create`, 4 minutes, résultat
identique.

### 19. Qu'est-ce qu'un manifest Kubernetes ?

*Explain what is a K8s manifest.*

**Réponse à dire :** Un manifest est un fichier YAML (ou JSON) qui décrit
**l'état souhaité** d'un ou plusieurs objets Kubernetes. Il a quatre parties :
`apiVersion` (le groupe et la version de l'API), `kind` (le type d'objet),
`metadata` (nom, étiquettes, namespace) et `spec` (ce que je veux). Kubernetes
y ajoute lui-même un `status`, l'état réel. `kubectl apply -f fichier.yaml`
l'envoie à l'API server, qui le stocke ; les contrôleurs le réalisent. C'est
**déclaratif** : je dis quoi, pas comment, et réappliquer un fichier inchangé
ne change rien.

**Preuve :**

```console
$ head -21 Manifests/inventory-app.yaml | grep -vE '^#|^$'
apiVersion: v1
kind: Service
metadata:
  name: inventory-app
  labels:
    app: inventory-app
    app.kubernetes.io/part-of: orchestrator
spec:
  type: ClusterIP
  selector:
    app: inventory-app
  ports:
    - name: http
      port: 8080
      targetPort: http
$ kubectl apply -f Manifests/inventory-app.yaml
service/inventory-app unchanged
deployment.apps/inventory-app unchanged
horizontalpodautoscaler.autoscaling/inventory-app unchanged
```

`unchanged` trois fois : l'état réel correspond déjà au fichier.

### 20. Expliquer chaque manifest

*Explain each K8s manifests.*

**Réponse à dire**, fichier par fichier (le détail est en README [§7](README.md#7-les-manifests-expliqués)) :

| Manifest | Objets | Ce qu'il fait |
|---|---|---|
| `storage.yaml` | StorageClass `nfs` + 3 PersistentVolumes | Déclare les trois répertoires NFS du master comme volumes de 1 Gio, politique `Retain`, chacun étiqueté pour être réclamé par le bon StatefulSet |
| `inventory-database.yaml` | Service headless + StatefulSet `inventory-db` | PostgreSQL 17, pod `inventory-db-0`, identifiants depuis `inventory-db-secret`, sondes `pg_isready`, une PVC sur le volume NFS, non-root uid 70 |
| `billing-database.yaml` | Service headless + StatefulSet `billing-db` | Identique pour la base `orders`, pod `billing-db-0` |
| `rabbitmq.yaml` | ConfigMap + Service headless + StatefulSet `rabbitmq` | Courtier RabbitMQ 4 avec volume (la file survit à un redémarrage) ; le ConfigMap aligne son seuil mémoire sur la limite du conteneur |
| `inventory-app.yaml` | Service ClusterIP + Deployment + HPA | API films sur 8080, sans champ `replicas` (le HPA décide : 1 à 3 pods à 60 % de CPU), sonde `/health`, réplicas répartis sur les deux nœuds |
| `billing-app.yaml` | Service headless + StatefulSet `billing-app` | Consommateur de la file, un seul réplica à identité stable, comme le sujet l'exige |
| `api-gateway.yaml` | Service `LoadBalancer` + Deployment + HPA | Point d'entrée sur le port 3000 des deux nœuds, relaie `/api/movies` et publie `/api/billing` dans RabbitMQ, HPA 1 à 3 à 60 % |
| `secrets/*.yaml` | 3 Secrets `Opaque` | `username` et `password` des deux bases et de RabbitMQ, générés localement |
| `bonus/*.yaml` | Namespace + 2 Deployments + RBAC | Tableaux de bord Headlamp et Dozzle |

Points à mettre en avant si l'auditeur creuse : les **sondes** (startup,
readiness, liveness), les **limites de ressources** sur chaque conteneur, et le
**`securityContext`** (non-root, système de fichiers en lecture seule, aucune
capacité Linux).

**Preuve :** ouvrir n'importe quel fichier : chaque bloc est commenté.

```console
$ grep -c '^ *#' Manifests/*.yaml
Manifests/api-gateway.yaml:21
Manifests/billing-app.yaml:12
Manifests/billing-database.yaml:18
Manifests/inventory-app.yaml:16
Manifests/inventory-database.yaml:18
Manifests/rabbitmq.yaml:19
Manifests/storage.yaml:16
```

### 21. L'étudiant a-t-il répondu correctement ?

*Did the student reply correctly to the questions?*

Point coché si les trois réponses précédentes sont données.

---

## H. Les secrets

### 22. Tous les identifiants utilisés sont-ils présents dans les secrets ?

*Are all the used credentials and passwords present in the secrets?*

**Réponse :** Oui. L'application utilise trois comptes — la base d'inventaire,
la base de facturation et RabbitMQ — et chacun a son Secret avec deux clés,
`username` et `password`. Chaque pod ne reçoit que les secrets dont il a
besoin : la passerelle ne connaît aucun mot de passe de base. Les valeurs sont
encodées en base64 (ce n'est pas un chiffrement) : c'est un Secret Kubernetes
standard ; en production on ajouterait le chiffrement au repos ou un
gestionnaire externe.

**Preuve :**

```console
$ kubectl get secrets
NAME                  TYPE     DATA   AGE
billing-db-secret     Opaque   2      2d21h
inventory-db-secret   Opaque   2      2d21h
rabbitmq-secret       Opaque   2      2d21h
$ kubectl get secrets -o json | head -12
{
    "apiVersion": "v1",
    "items": [
        {
            "apiVersion": "v1",
            "data": {
                "password": "<le mot de passe encodé en base64, masqué ici>",
                "username": "YmlsbGluZ191c2Vy"
            },
            "kind": "Secret",
            "metadata": {
                "annotations": {
$ kubectl get secret billing-db-secret -o jsonpath='{.data.username}' | base64 -d; echo
billing_user
$ kubectl get pod billing-app-0 -o jsonpath='{range .spec.containers[0].env[*]}{.name}{"\t"}{.valueFrom.secretKeyRef.name}{"\n"}{end}' | grep secret
DB_USER	billing-db-secret
DB_PASSWORD	billing-db-secret
RABBITMQ_USER	rabbitmq-secret
RABBITMQ_PASSWORD	rabbitmq-secret
```

Détail : README [§8](README.md#8-secrets).

---

## I. Les ressources déployées

### 23. Toutes les applications demandées sont-elles déployées ?

*Are all the required applications deployed?*

**Réponse :** Oui, les six, chacune sur le port demandé :

| Composant du sujet | Objet | Port |
|---|---|---|
| `inventory-database` | StatefulSet `inventory-db` + Service | 5432 |
| `billing-database` | StatefulSet `billing-db` + Service | 5432 |
| `inventory-app` | Deployment `inventory-app` + Service | 8080 |
| `billing-app` | StatefulSet `billing-app` + Service | 8080 |
| `RabbitMQ` | StatefulSet `rabbitmq` + Service | 5672 |
| `api-gateway-app` | Deployment `api-gateway` + Service `LoadBalancer` | 3000 |

**Preuve :**

```console
$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/api-gateway-7ff5cbccf9-8n4r7     1/1     Running   0          79s
pod/billing-app-0                    1/1     Running   0          92s
pod/billing-db-0                     1/1     Running   0          70s
pod/inventory-app-7d56f997b8-q5vjp   1/1     Running   0          46s
pod/inventory-db-0                   1/1     Running   0          42h
pod/rabbitmq-0                       1/1     Running   0          42h

NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP                     PORT(S)          AGE
service/api-gateway     LoadBalancer   10.43.76.154   192.168.56.110,192.168.56.111   3000:32138/TCP   2d21h
service/billing-app     ClusterIP      None           <none>                          8080/TCP         2d21h
service/billing-db      ClusterIP      None           <none>                          5432/TCP         2d21h
service/inventory-app   ClusterIP      10.43.29.76    <none>                          8080/TCP         2d21h
service/inventory-db    ClusterIP      None           <none>                          5432/TCP         2d21h
service/kubernetes      ClusterIP      10.43.0.1      <none>                          443/TCP          2d22h
service/rabbitmq        ClusterIP      None           <none>                          5672/TCP         2d21h

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/api-gateway     1/1     1            1           2d21h
deployment.apps/inventory-app   1/1     1            1           2d21h

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/api-gateway-7ff5cbccf9     1         1         1       2d21h
replicaset.apps/inventory-app-7d56f997b8   1         1         1       2d21h

NAME                            READY   AGE
statefulset.apps/billing-app    1/1     2d21h
statefulset.apps/billing-db     1/1     2d21h
statefulset.apps/inventory-db   1/1     2d21h
statefulset.apps/rabbitmq       1/1     2d21h

NAME                                                REFERENCE                  TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/api-gateway     Deployment/api-gateway     cpu: 1%/60%   1         3         1          2d21h
horizontalpodautoscaler.autoscaling/inventory-app   Deployment/inventory-app   cpu: 1%/60%   1         3         1          2d21h
```

(Les pods jeunes de quelques secondes viennent des démonstrations des entrées
3, 25 et 28, jouées juste avant cette capture.) Les Services `ClusterIP None`
sont des Services *headless* : le nom DNS pointe directement sur le pod, ce
qu'exige un StatefulSet. La file existe bien dans RabbitMQ :

```console
$ kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages durable
name	messages	durable
billing_queue	0	true
```

### 24. Chaque application a-t-elle la bonne configuration ?

*Do all apps deploy with the correct configuration?*

**Réponse :** Oui, point par point de la grille :
- **les bases sont des StatefulSets** avec des volumes qui suivent le pod
  d'un nœud à l'autre (volumes NFS, démonstration à l'entrée 44) ;
- **`api-gateway` et `inventory-app` sont des Deployments** mis à l'échelle
  automatiquement par un HPA : **min 1, max 3, seuil 60 % de CPU** ;
- **`billing-app` est un StatefulSet.**

**Preuve :**

```console
$ kubectl get hpa
NAME            REFERENCE                  TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
api-gateway     Deployment/api-gateway     cpu: 1%/60%   1         3         1          2d21h
inventory-app   Deployment/inventory-app   cpu: 1%/60%   1         3         1          2d21h
$ grep -nE 'minReplicas|maxReplicas|averageUtilization' Manifests/api-gateway.yaml
139:  minReplicas: 1
140:  maxReplicas: 3
148:          averageUtilization: 60
$ kubectl get pv
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                         STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
billing-db-pv     1Gi        RWO            Retain           Bound    default/data-billing-db-0     nfs            <unset>                          2d21h
inventory-db-pv   1Gi        RWO            Retain           Bound    default/data-inventory-db-0   nfs            <unset>                          2d21h
rabbitmq-pv       1Gi        RWO            Retain           Bound    default/data-rabbitmq-0       nfs            <unset>                          2d21h
```

**Démonstration de l'autoscaling** (3 minutes, la plus parlante de l'audit) :

```console
$ ./orchestrator.sh load
== autoscalers before the load
NAME            REFERENCE                  TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
api-gateway     Deployment/api-gateway     cpu: 1%/60%   1         3         1          25h
inventory-app   Deployment/inventory-app   cpu: 1%/60%   1         3         1          25h
== starting 8 request loops against http://api-gateway:3000/api/movies/ for 180s
-- 13:26:51
HPA             CPU%   TARGET%   REPLICAS   DESIRED
api-gateway     49     60        1          1
inventory-app   24     60        1          1
-- 13:27:06
HPA             CPU%   TARGET%   REPLICAS   DESIRED
api-gateway     364    60        1          3
inventory-app   156    60        1          3
-- 13:27:21
HPA             CPU%   TARGET%   REPLICAS   DESIRED
api-gateway     368    60        3          3
inventory-app   176    60        3          3
[...]
the autoscalers scale back to 1 replica 1 to 2 minutes from now (kubectl get hpa -w, Ctrl-C to leave)
deleting the load generator
```

À 49 % (sous le seuil) rien ne bouge ; à 364 % le HPA passe à 3 pods, le
maximum, en 15 secondes. Le pourcentage est calculé sur la **demande** de CPU
(`requests: 100m`), pas sur la limite : 364 % = 364 m consommés. Le retour à
1 pod prend 1 à 2 minutes : fenêtre de stabilisation volontaire de 60 s, pour
éviter que les pods n'apparaissent et disparaissent à chaque pic.

---

## J. Questions : StatefulSet, Deployment, scaling, load balancer

Ces six questions valident un seul point de la grille (entrée 31).

### 25. Qu'est-ce qu'un StatefulSet ?

*What is StatefulSet in K8s?*

**Réponse à dire :** Un StatefulSet est le contrôleur pour les applications
**avec état** : bases de données, files de messages, tout ce qui a des
données propres. Il garantit à chaque pod trois choses :
- une **identité stable** : un nom ordinal fixe (`billing-db-0`), conservé à
  travers les redémarrages et les replanifications, et un nom DNS stable grâce
  au Service headless ;
- un **stockage stable** : chaque pod reçoit sa propre PVC
  (`volumeClaimTemplates` → `data-billing-db-0`), qui le suit sur n'importe
  quel nœud et n'est pas supprimée avec lui ;
- un **ordre** : création `0, 1, 2…`, chaque pod attendant que le précédent
  soit prêt, suppression en ordre inverse, mise à jour un par un.

**Preuve :**

```console
$ kubectl get statefulset billing-db -o jsonpath='{.spec.serviceName} {.spec.volumeClaimTemplates[0].metadata.name}{"\n"}'
billing-db data
$ kubectl delete pod billing-db-0
pod "billing-db-0" deleted from default namespace
$ kubectl get pods -l app=billing-db
NAME           READY   STATUS    RESTARTS   AGE
billing-db-0   1/1     Running   0          11s
```

Le pod revient avec **le même nom** et retrouve sa PVC `data-billing-db-0`.

### 26. Qu'est-ce qu'un Deployment ?

*What is deployment in K8s?*

**Réponse à dire :** Un Deployment est le contrôleur pour les applications
**sans état** : API, front, passerelle. Il gère un ReplicaSet qui maintient N
pods **interchangeables**, aux noms aléatoires (`api-gateway-7ff5cbccf9-8n4r7`),
et il orchestre les mises à jour progressives (*rolling update* : les nouveaux
pods remplacent les anciens un par un, sans coupure) et les retours arrière
(`kubectl rollout undo`). Les pods n'ont pas chacun leur volume : ils sont
identiques et remplaçables.

**Preuve :**

```console
$ kubectl get deployment api-gateway -o jsonpath='{.spec.strategy.type} {.spec.template.spec.containers[0].image}{"\n"}'
RollingUpdate clecart/api-gateway:1.0.0
$ kubectl rollout history deployment/api-gateway
deployment.apps/api-gateway
REVISION  CHANGE-CAUSE
1         <none>
```

### 27. Quelle est la différence entre Deployment et StatefulSet ?

*What is the difference between deployment and StatefulSet in K8s?*

**Réponse à dire :**

| | Deployment | StatefulSet |
|---|---|---|
| Pour | applications **sans état** (API, front) | applications **avec état** (bases, files, consommateurs) |
| Noms des pods | aléatoires, interchangeables | ordinaux, stables (`-0`, `-1`) |
| Stockage | partagé ou aucun | **une PVC par pod**, conservée |
| Réseau | un Service répartit entre tous | Service headless : un nom DNS par pod |
| Démarrage, arrêt | tous en parallèle | un par un, dans l'ordre |
| Mise à l'échelle | libre, adaptée au HPA | possible, mais chaque réplica est une instance distincte avec ses données |

En une phrase : **le Deployment gère des copies identiques, le StatefulSet
gère des individus.**

**Preuve :** dans mon cluster, les deux cohabitent : passerelle et inventaire
en Deployment (noms aléatoires, gérés par un ReplicaSet), bases, RabbitMQ et
facturation en StatefulSet (noms `-0`).

```console
$ kubectl get pods -o custom-columns='POD:.metadata.name,CONTRÔLEUR:.metadata.ownerReferences[0].kind'
POD                              CONTRÔLEUR
api-gateway-7ff5cbccf9-h6nsl     ReplicaSet
billing-app-0                    StatefulSet
billing-db-0                     StatefulSet
inventory-app-7d56f997b8-lmhlr   ReplicaSet
inventory-db-0                   StatefulSet
rabbitmq-0                       StatefulSet
```

### 28. Qu'est-ce que la mise à l'échelle, et pourquoi l'utiliser ?

*What is scaling, and why do we use it?*

**Réponse à dire :** La mise à l'échelle, c'est adapter la capacité à la
charge. **Horizontale** : ajouter ou retirer des copies (pods) ; **verticale** :
donner plus de CPU ou de mémoire à chaque copie. Kubernetes automatise
l'horizontale avec le HorizontalPodAutoscaler : ici, la passerelle et
l'inventaire passent de 1 à 3 pods dès que le CPU moyen dépasse 60 % de la
demande, et redescendent quand la charge retombe.

Pourquoi : **tenir les pics** sans dégrader les temps de réponse, **ne
consommer que le nécessaire** le reste du temps, et **gagner en
disponibilité** (plusieurs copies sur plusieurs nœuds : la perte d'un nœud
n'arrête pas le service).

**Preuve :** la démonstration `./orchestrator.sh load` de l'entrée 24, et
manuellement :

```console
$ kubectl scale deployment inventory-app --replicas=3
deployment.apps/inventory-app scaled
$ kubectl get pods -l app=inventory-app -o wide --no-headers | awk '{print $1, $3, $7}'
inventory-app-7d56f997b8-9jcq9 Running master
inventory-app-7d56f997b8-lmhlr Running master
inventory-app-7d56f997b8-q5vjp Running agent
```

Trois copies, réparties sur les deux nœuds. (Le HPA ramène ensuite à 1 tout
seul, puisque le CPU est bas.)

### 29. Qu'est-ce qu'un load balancer, et quel est son rôle ?

*What is a load balancer, and what is its role?*

**Réponse à dire :** Un répartiteur de charge est un composant qui **reçoit le
trafic sur un point d'entrée unique et le distribue entre plusieurs
instances** d'un service. Son rôle : répartir la charge, n'envoyer qu'aux
instances saines (grâce aux sondes de readiness), et masquer l'ajout ou le
retrait d'instances — mise à l'échelle, pannes, mises à jour — au client, qui
ne voit qu'une adresse.

Dans mon cluster, à deux niveaux : le Service `api-gateway` de type
**LoadBalancer** (ServiceLB de K3s) ouvre le port 3000 sur chaque nœud et
répartit entre les pods de passerelle ; le Service ClusterIP `inventory-app`
répartit, via kube-proxy, entre les pods d'inventaire.

**Preuve :**

```console
$ kubectl get service api-gateway
NAME          TYPE           CLUSTER-IP     EXTERNAL-IP                     PORT(S)          AGE
api-gateway   LoadBalancer   10.43.76.154   192.168.56.110,192.168.56.111   3000:32138/TCP   2d21h
$ curl -s http://192.168.56.111:3000/health     # le port 3000 répond aussi sur l'agent
{"status":"ok","rabbitmq":"connected"}
$ kubectl get endpointslices -l kubernetes.io/service-name=inventory-app -o jsonpath='{.items[0].endpoints[*].addresses[0]}{"\n"}'
10.42.0.64 10.42.1.65 10.42.0.70
```

Avec les 3 pods d'inventaire de l'entrée 28, le Service a trois adresses de
destination : une sur l'agent (`10.42.1.x`), deux sur le master (`10.42.0.x`).

### 30. Pourquoi ne pas déployer la base de données en Deployment ?

*Why we don't put the database as a deployment?*

**Réponse à dire :** Parce qu'une base a un **état** que ses copies ne
partagent pas :
- un Deployment donne à ses pods des noms aléatoires et **un même volume** à
  tous : deux PostgreSQL écrivant dans le même répertoire corrompraient les
  données (et avec `ReadWriteOnce`, le second ne démarrerait même pas) ;
- pendant une mise à jour, un Deployment démarre le nouveau pod **avant** de
  tuer l'ancien : deux serveurs sur les mêmes fichiers ;
- une base a besoin d'une identité stable (nom DNS fixe, rôle
  primaire/réplique) et d'un arrêt et d'un démarrage ordonnés.

Le StatefulSet fournit exactement cela : un volume par pod qui le suit, un nom
fixe, un seul pod à la fois pendant les mises à jour.

**Preuve :** le StatefulSet `billing-db` déclare un réplica, une mise à jour
`RollingUpdate` et une gestion des pods `OrderedReady` (un par un, dans
l'ordre).

```console
$ kubectl get statefulset billing-db -o jsonpath='{.spec.replicas} {.spec.updateStrategy.type} {.spec.podManagementPolicy}{"\n"}'
1 RollingUpdate OrderedReady
```

### 31. L'étudiant a-t-il répondu correctement à toutes ces questions ?

*Did the student reply correctly to all the above questions?*

Point coché si les six réponses précédentes sont données.

---

## K. API inventaire

### 32. `POST /api/movies/` répond-il 200 ?

*Open Postman and make a POST request to `http://[GATEWAY_IP]:[GATEWAY_PORT]/api/movies/` … Can you confirm the response was the success code 200?*

**Réponse :** Oui : la passerelle relaie la requête à `inventory-app`, qui
insère le film dans `inventory-db` et renvoie l'enregistrement créé.

**Preuve :**

```console
$ curl -s -w '\n-> HTTP %{http_code}\n' -X POST http://192.168.56.110:3000/api/movies/ \
    -H 'Content-Type: application/json' \
    -d '{"title":"A new movie","description":"Very short description"}'
{"id":7,"title":"A new movie","description":"Very short description","created_at":"2026-09-25T07:22:31.873Z"}
-> HTTP 200
```

Dans Postman : `POST`, URL `http://192.168.56.110:3000/api/movies/`, *Body* →
*raw* → *JSON*, coller le corps, *Send* : `Status: 200 OK`.

### 33. `GET /api/movies/` répond-il 200 avec le dernier film en JSON ?

*In Postman make a GET request … Can you confirm the response was success code 200 and the body of the response is in json with the information of the last added movie?*

**Réponse :** Oui : une liste JSON, dont le dernier élément est le film qu'on
vient d'ajouter (`id 7`).

**Preuve :**

```console
$ curl -s -w '\n-> HTTP %{http_code}\n' http://192.168.56.110:3000/api/movies/
[{"id":1,"title":"A new movie","description":"Very short description","created_at":"2026-09-22T09:23:30.657Z"}, [...] ,{"id":7,"title":"A new movie","description":"Very short description","created_at":"2026-09-25T07:22:31.873Z"}]
-> HTTP 200
```

Les films 1 à 6 proviennent des tests des jours précédents : ils prouvent au
passage que les données survivent aux arrêts et redémarrages du cluster.

---

## L. API facturation

### 34. `POST /api/billing/` répond-il 200 ?

*Open Postman and make a POST request to `…/api/billing/` … Can you confirm the response was success code 200?*

**Réponse :** Oui : la passerelle dépose le message dans la file RabbitMQ et
répond dès que le courtier a confirmé. `billing-app` le consomme ensuite et
l'enregistre dans `billing-db`.

**Preuve :**

```console
$ curl -s -w '\n-> HTTP %{http_code}\n' -X POST http://192.168.56.110:3000/api/billing/ \
    -H 'Content-Type: application/json' \
    -d '{"user_id":"20","number_of_items":"99","total_amount":"250"}'
{"message":"Message posted"}
-> HTTP 200
$ kubectl logs billing-app-0 | grep 'order stored' | tail -1
{"time":"2026-09-25T07:22:31.991Z","level":"info","msg":"order stored","id":13,"userId":20}
```

### 35. `billing-app` est-il correctement arrêté ?

*Stop the billing-app container. Can you confirm the billing-app container was correctly stopped?*

**Réponse :** Sous Kubernetes, on n'arrête pas un conteneur à la main : si je
supprimais le pod, le StatefulSet le recréerait aussitôt (c'est
l'auto-réparation). La bonne méthode est de ramener le StatefulSet à **0
réplica** : le pod disparaît et rien ne le recrée.

**Preuve :**

```console
$ kubectl scale statefulset billing-app --replicas=0
statefulset.apps/billing-app scaled
$ kubectl get statefulset billing-app
NAME          READY   AGE
billing-app   0/0     2d21h
$ kubectl get pods -l app=billing-app
No resources found in default namespace.
```

`0/0` et aucun pod : le service de facturation est arrêté.

### 36. `POST /api/billing/` répond-il 200 même sans `billing-app` ?

*Open Postman and make a POST request to `…/api/billing/` … Can you confirm the response was success code 200 even if the billing_app is not working?*

**Réponse :** Oui, parce que la passerelle **ne parle jamais à `billing-app`** :
elle dépose le message dans RabbitMQ, et la file le garde. C'est tout l'intérêt
de l'architecture : la facturation peut tomber sans qu'aucune commande ne soit
perdue ni refusée.

**Preuve :**

```console
$ curl -s -w '\n-> HTTP %{http_code}\n' -X POST http://192.168.56.110:3000/api/billing/ \
    -H 'Content-Type: application/json' \
    -d '{"user_id":"22","number_of_items":"10","total_amount":"50"}'
{"message":"Message posted"}
-> HTTP 200
$ kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages
Timeout: 60.0 seconds ...
Listing queues for vhost / ...
name	messages
billing_queue	1
```

Un message attend dans la file.

---

## M. Base de données de facturation

### 37. La base `orders` est-elle listée ?

*Run `kubectl exec -it pods/billing-db-0 -- sh` to enter into the pod, then run `sudo -i -u postgres`, then `psql` and once in the database enter `\l`. Can you confirm the orders database is listed?*

**Réponse :** Oui. Une différence avec la commande de la grille, à expliquer :
**`sudo -i -u postgres` est inutile, et `sudo` n'existe même pas dans
l'image**, parce que le conteneur tourne **déjà** sous l'utilisateur `postgres`
(uid 70), jamais sous root — c'est une règle de sécurité de mes images. Les
variables `PGUSER` et `PGDATABASE` sont préremplies dans le pod, donc `psql`
seul ouvre directement la base `orders` avec le compte `billing_user`.

**Preuve :**

```console
$ kubectl exec -it pods/billing-db-0 -- sh
/ $ whoami
postgres
/ $ psql
psql (17.11)
Type "help" for help.

orders=# \l
                                                      List of databases
   Name    |    Owner     | Encoding | Locale Provider | Collate | Ctype | Locale | ICU Rules |       Access privileges
-----------+--------------+----------+-----------------+---------+-------+--------+-----------+-------------------------------
 orders    | billing_user | UTF8     | libc            | C       | C     |        |           |
 postgres  | billing_user | UTF8     | libc            | C       | C     |        |           |
 template0 | billing_user | UTF8     | libc            | C       | C     |        |           | =c/billing_user              +
           |              |          |                 |         |       |        |           | billing_user=CTc/billing_user
 template1 | billing_user | UTF8     | libc            | C       | C     |        |           | =c/billing_user              +
           |              |          |                 |         |       |        |           | billing_user=CTc/billing_user
(4 rows)
```

La ligne `orders` est là. (Sortir de `psql` : `\q`, puis `exit`.)

### 38. La commande `user_id = 20` est-elle présente ?

*Still in psql run `\c orders` and then `TABLE orders;`. Can you confirm the order with user_id = 20 is listed properly?*

**Réponse :** Oui : la commande envoyée pendant que `billing-app` tournait
(entrée 34) est enregistrée, c'est la dernière ligne de la table.

**Preuve :**

```console
orders=# \c orders
You are now connected to database "orders" as user "billing_user".
orders=# TABLE orders;
 id | user_id | number_of_items | total_amount |          created_at
----+---------+-----------------+--------------+-------------------------------
[...]
 12 |      22 |              10 |        50.00 | 2026-09-23 11:25:37.668561+00
 13 |      20 |              99 |       250.00 | 2026-09-25 07:22:32.832081+00
(13 rows)
```

Sans entrer dans le pod, la même chose en une commande :

```console
$ kubectl exec billing-db-0 -- psql -c 'TABLE orders'
```

### 39. La commande `user_id = 22` est-elle absente ?

*Can you confirm the order with user_id = 22 is NOT listed?*

**Réponse :** Oui, elle est absente : elle attend dans la file RabbitMQ tant
que `billing-app` est arrêté. La dernière ligne de la table est la commande
20 (`id 13`, 07:22:32) ; rien n'est apparu depuis.

**Preuve :**

```console
$ kubectl exec billing-db-0 -- psql -tAc "SELECT count(*) FROM orders WHERE created_at > now() - interval '5 minutes' AND user_id = 22"
0
$ kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages | tail -1
billing_queue	1
```

Zéro commande récente de l'utilisateur 22 en base, un message en attente.

> La ligne `12 | 22` visible plus haut date du 23 septembre : le scénario a
> été joué plusieurs fois. Ce qui compte est qu'aucune ligne 22 n'est apparue
> **depuis** l'arrêt de `billing-app` : comparer `created_at` à l'heure de la
> requête.

---

## N. Résilience de la file de messages

### 40. `billing-app` redémarre-t-il correctement ?

*Start the billing-app container. Can you confirm the billing-app container was correctly stopped?* (la grille reprend la phrase de l'entrée 35 ; il s'agit ici du redémarrage)

**Réponse :** Oui : je remets le StatefulSet à 1 réplica, le pod
`billing-app-0` est recréé, se connecte à la base et à RabbitMQ, et consomme
immédiatement le message resté en file.

**Preuve :**

```console
$ kubectl scale statefulset billing-app --replicas=1
statefulset.apps/billing-app scaled
$ kubectl rollout status statefulset/billing-app
partitioned roll out complete: 1 new pods have been updated...
$ kubectl get pods billing-app-0
NAME            READY   STATUS    RESTARTS   AGE
billing-app-0   1/1     Running   0          6s
$ kubectl logs billing-app-0 | grep -E 'consumer ready|order stored'
{"time":"2026-09-25T07:22:40.424Z","level":"info","msg":"rabbitmq consumer ready","queue":"billing_queue"}
{"time":"2026-09-25T07:22:40.431Z","level":"info","msg":"order stored","id":14,"userId":22}
```

Sept millisecondes entre la connexion à la file et l'enregistrement de la
commande en attente.

### 41. La commande `user_id = 22` est-elle maintenant présente ?

*Can you confirm the order with user_id = 22 is now listed properly?*

**Réponse :** Oui : la commande envoyée pendant l'arrêt est maintenant en
base (`id 14`), et la file est vide. **Aucune commande n'a été perdue** pendant
la panne du service de facturation : c'est la résilience apportée par la file
de messages.

**Preuve :**

```console
$ kubectl exec billing-db-0 -- psql -c 'TABLE orders' | tail -3
 14 |      22 |              10 |        50.00 | 2026-09-25 07:22:41.291076+00
(14 rows)

$ kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages | tail -1
billing_queue	0
```

**Tout le scénario 32 → 41 en une commande**, si l'auditeur préfère :

```console
$ ./orchestrator.sh test
[...]
== Summary ==
  PASS  GET /health -> HTTP 200
  PASS  POST /api/movies/ {"title":"A new movie","description":"Very short description"} -> HTTP 200
  PASS  GET /api/movies/ -> HTTP 200
  PASS  GET /api/movies/ returns a JSON list containing "A new movie"
  PASS  orders of user 20 in billing-db: 0
  PASS  POST /api/billing/ {"user_id":"20","number_of_items":"99","total_amount":"250"} -> HTTP 200
  PASS  order of user 20 stored: 0 -> 1
  PASS  billing-app is stopped (no billing-app pod left)
  PASS  POST /api/billing/ {"user_id":"22","number_of_items":"10","total_amount":"50"} -> HTTP 200
  PASS  queue billing_queue holds 1 message
  PASS  order of user 22 NOT stored yet (0 row(s))
  PASS  billing-app is running again
  PASS  queue billing_queue is drained (0 message)
  PASS  order of user 22 stored: 0 -> 1
All 14 checks passed
```

---

## O. Les composants de Kubernetes

### 42. Expliquer tous les composants de Kubernetes en moins de 15 minutes

*In less than 15 minutes and with the help of Google the student must explain all Kubernetes components and their roles. Can the learner explain the K8s components in less than 15 minutes?*

Le schéma de la grille est celui de la documentation officielle :
<https://kubernetes.io/images/docs/components-of-kubernetes.svg>. L'afficher, et
suivre ce plan en une dizaine de minutes ; les preuves se lancent en parallèle
sur le cluster.

**Plan de l'exposé :**

**1. La structure (1 min).** Un cluster, c'est un **plan de contrôle** qui
décide, et des **nœuds** qui exécutent. Chez moi, le plan de contrôle est sur
la VM `master`, qui exécute aussi des pods ; la VM `agent` n'exécute que des
pods. Dans K3s, tout le plan de contrôle tient dans un seul processus,
`k3s server`.

**2. Le plan de contrôle (4 min).**

| Composant | Rôle | Dans mon cluster |
|---|---|---|
| **kube-apiserver** | La **porte d'entrée unique** : API REST sur le port 6443. Il authentifie, autorise (RBAC), valide et enregistre chaque objet. `kubectl`, les kubelets et les contrôleurs ne parlent qu'à lui, jamais entre eux. | `https://192.168.56.110:6443`, dans `k3s server` |
| **etcd** | La **mémoire du cluster** : base clé-valeur distribuée qui stocke l'état complet (tous les objets). Seul l'API server y accède. | Remplacé par **SQLite** via Kine (`/var/lib/rancher/k3s/server/db/state.db`) ; K3s passe à etcd en haute disponibilité |
| **kube-scheduler** | Choisit **un nœud pour chaque nouveau pod** : il filtre les nœuds possibles (CPU et mémoire demandés, affinités, taints, volumes), puis les classe. Il ne lance rien lui-même : il écrit le nom du nœud dans le pod. | C'est lui qui a mis `billing-app-0` sur `agent` et `rabbitmq-0` sur `master` |
| **kube-controller-manager** | Les **contrôleurs**, boucles de réconciliation : Deployment et ReplicaSet (le bon nombre de pods), StatefulSet, nœuds (détection d'un nœud mort), endpoints, HPA, volumes, jobs, ServiceAccounts. Chacun compare sans arrêt l'état réel à l'état voulu. | Quand je supprime un pod, c'est le contrôleur ReplicaSet qui en recrée un |
| **cloud-controller-manager** | Le lien avec un fournisseur de cloud : adresses des nœuds, load balancers, disques. Facultatif hors cloud. | K3s embarque le sien : il fournit **ServiceLB**, qui réalise mon Service `LoadBalancer` sur le port 3000 |

**3. Les nœuds (3 min).**

| Composant | Rôle | Dans mon cluster |
|---|---|---|
| **kubelet** | **L'agent de chaque nœud.** Il surveille l'API server, reçoit les pods qui lui sont assignés, demande au runtime de les démarrer, monte leurs volumes, exécute les sondes de santé, et remonte l'état des pods et du nœud. | Dans `k3s server` sur le master, `k3s agent` sur l'agent ; c'est lui qui a monté le volume NFS et qui arrête proprement les pods à l'extinction |
| **kube-proxy** | Réalise les **Services** : il programme les règles réseau (iptables/nftables) pour que l'IP virtuelle d'un Service (`10.43.x.x`) soit répartie vers les IP des pods. | Embarqué dans K3s sur les deux nœuds |
| **Container runtime** | Exécute réellement les conteneurs : télécharge les images, crée les namespaces et cgroups. Interface CRI. | **containerd** 2.3, embarqué (`sudo k3s crictl ps` sur un nœud) |
| **Pod** | La plus petite unité déployable : un ou plusieurs conteneurs qui partagent une IP et des volumes. | Mes 6 pods d'application |

**4. Les modules complémentaires (1 min).**

| Composant | Rôle | Dans mon cluster |
|---|---|---|
| **CNI** (réseau) | Donne une IP à chaque pod et relie les pods de tous les nœuds | **flannel** en VXLAN, sur l'interface privée `eth1` (`10.42.0.x` sur le master, `10.42.1.x` sur l'agent) |
| **DNS** | Résout les noms de Services : `inventory-db` → IP du pod | **CoreDNS** |
| **metrics-server** | Mesure CPU et mémoire pour `kubectl top` et les HPA | inclus dans K3s |
| Stockage, tableau de bord | provisionnement de volumes, interface web | `local-path` (non utilisé, mes volumes sont NFS) ; Headlamp en bonus |

**5. Le trajet d'un `kubectl apply` (1 min), pour relier le tout :**

1. `kubectl apply -f api-gateway.yaml` → le **kube-apiserver** authentifie,
   valide et enregistre le Deployment dans **etcd/SQLite** ;
2. le contrôleur Deployment (**kube-controller-manager**) crée un ReplicaSet,
   dont le contrôleur crée un Pod sans nœud ;
3. le **kube-scheduler** voit ce pod non placé et lui attribue un nœud ;
4. le **kubelet** de ce nœud voit le pod, demande l'image et le démarrage à
   **containerd**, monte les volumes, lance les sondes, et publie `Running`
   puis `Ready` ;
5. le contrôleur d'endpoints ajoute l'IP du pod au Service ; **kube-proxy**
   met à jour les règles réseau : le pod reçoit du trafic.

**Preuves à montrer pendant l'exposé :**

```console
$ kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
coredns-54996dc9b4-5nwmx                  1/1     Running   0          42h
local-path-provisioner-77b9867795-7b5kv   1/1     Running   0          42h
metrics-server-6dc596dfb8-97mct           1/1     Running   0          42h
svclb-api-gateway-b39e38ce-7wv6t          1/1     Running   0          101s
svclb-api-gateway-b39e38ce-rr4ms          1/1     Running   0          81s
svclb-dozzle-a24b0d46-2lf45               1/1     Running   0          81s
svclb-dozzle-a24b0d46-djcr8               1/1     Running   0          101s
svclb-headlamp-035556ed-5x6gz             1/1     Running   0          81s
svclb-headlamp-035556ed-ph2xt             1/1     Running   0          101s
$ kubectl get --raw '/readyz?verbose' | tail -3
[+]poststarthook/apiservice-openapiv3-controller ok
[+]shutdown ok
readyz check passed
$ vagrant ssh master -c 'sudo k3s crictl ps' | head -4
CONTAINER           IMAGE               CREATED              STATE               NAME                     ATTEMPT             POD ID
3708697c762f3       b334b1ac64c4d       About a minute ago   Running             rabbitmq                 0                   224ae8653a0af
83aab4493016c       36534855e04b8       About a minute ago   Running             billing-db               0                   6e228dbda4508
b1f0a08ae02a8       683316f41426e       About a minute ago   Running             local-path-provisioner   0                   44e4210edb277
$ vagrant ssh agent -c 'sudo systemctl status k3s-agent --no-pager | head -3'
● k3s-agent.service - Lightweight Kubernetes
     Loaded: loaded (/etc/systemd/system/k3s-agent.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-09-25 07:20:39 UTC; 1min 25s ago
```

Les pods `svclb-*` sont ServiceLB : un par Service `LoadBalancer` et par nœud,
d'où les paires (`api-gateway`, et les deux tableaux de bord bonus).

Détail et schéma : README [§18](README.md#18-les-composants-de-kubernetes).

---

## P. Bonus

### 43. Ma propre solution *play-with-containers* est-elle utilisée ?

*+Did the student used his/her own play-with-container solution instead of the provided one?*

**Réponse :** Oui. Les six images sont construites depuis **mes** Dockerfiles
de *play-with-containers*, pas depuis ceux fournis par le sujet : Alpine 3.23,
Node.js 24, PostgreSQL 17, RabbitMQ 4.2, images multi-étapes, aucun conteneur
en root, `tini` en PID 1, aucune image préconstruite autre qu'`alpine`. Les
contextes complets sont dans `Dockerfiles/`.

**Preuve :**

```console
$ head -12 Dockerfiles/api-gateway/Dockerfile
# ---- Stage 1: install production dependencies only ----
FROM alpine:3.23 AS deps
RUN apk add --no-cache nodejs npm
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- Stage 2: minimal runtime image (no npm, non-root user) ----
FROM alpine:3.23
LABEL org.opencontainers.image.title="api-gateway-app" \
      org.opencontainers.image.description="API gateway: proxies /api/movies to inventory-app and publishes /api/billing orders to RabbitMQ" \
      org.opencontainers.image.authors="clecart"
$ kubectl exec billing-db-0 -- sh -c 'whoami; postgres --version; cat /etc/alpine-release'
postgres
postgres (PostgreSQL) 17.11
3.23.6
```

Les Dockerfiles du sujet utilisent `python:3.12-alpine` et `debian:bullseye`
avec PostgreSQL 13 : ce ne sont pas ceux-là.

### 44. Des bonus optionnels ont-ils été ajoutés ?

*+Did the student add any optional bonus?*

**Réponse :** Oui, cinq :

1. **Tableau de bord du cluster : Headlamp** (`./orchestrator.sh bonus`,
   <http://192.168.56.110:4466>). Le Kubernetes Dashboard historique est
   archivé ; Headlamp est son successeur, projet `kubernetes-sigs`. Connexion
   par un jeton émis à la demande, valable 24 h (`./orchestrator.sh bonus-token`).
2. **Tableau de bord des journaux : Dozzle** (<http://192.168.56.110:8888>) :
   les journaux de tous les pods en direct, avec un compte en lecture seule.
3. **Volumes NFS** : une base peut changer de nœud sans perdre ses données
   (démonstration ci-dessous).
4. **Arrêt propre des nœuds** : le kubelet arrête les pods avant l'extinction
   des VM, et `stop` cordonne les nœuds ; PostgreSQL redémarre sans
   récupération.
5. **Outillage** : scénario d'audit automatisé (`test`, 14 vérifications),
   démonstration des HPA (`load`), pods durcis (non-root, système de fichiers
   en lecture seule, aucune capacité Linux, pas de jeton d'API, limites de
   ressources), scripts vérifiés par shellcheck et hadolint.

**Preuve, les tableaux de bord :**

```console
$ ./orchestrator.sh bonus
==> deploying the dashboards
[...]
cluster dashboard (Headlamp): http://192.168.56.110:4466  (token: ./orchestrator.sh bonus-token)
logs dashboard (Dozzle):      http://192.168.56.110:8888
$ kubectl get pods -n dashboards
NAME                        READY   STATUS    RESTARTS   AGE
dozzle-59c5996f7d-kwpg4     1/1     Running   0          42h
headlamp-64fdccd575-7vpk6   1/1     Running   0          42h
```

**Preuve, une base qui change de nœud sans perdre ses données :**

```console
$ kubectl get pod inventory-db-0 -o wide --no-headers | awk '{print $1, $7}'
inventory-db-0 master
$ kubectl cordon master && kubectl delete pod inventory-db-0 && kubectl rollout status statefulset/inventory-db && kubectl uncordon master
[...]
$ kubectl get pod inventory-db-0 -o wide --no-headers | awk '{print $1, $7}'
inventory-db-0 agent
$ vagrant ssh agent -c 'mount | grep nfs' | cut -c1-90
192.168.56.110:/srv/nfs/k3s/inventory-db on /var/lib/kubelet/pods/0977f6ab-6cf7-4ebc-a9a2-
$ curl -s http://192.168.56.110:3000/api/movies/ | python3 -c 'import sys,json; print(len(json.load(sys.stdin)), "films")'
6 films
```

Le pod est passé du master à l'agent, l'agent a monté le volume par le réseau,
et les 6 films qu'il y avait ce jour-là sont toujours là.

### 45. Le projet est-il remarquable ?

*+Is this project an outstanding project?*

**À l'appréciation de l'auditeur.** Ce qu'il peut retenir : une infrastructure
entièrement reproductible en une commande et vérifiée de zéro ; aucun secret
versionné, même dans les manifests de Secrets ; un stockage réellement mobile
entre les nœuds ; un arrêt et un redémarrage propres, y compris après un
crash de la machine hôte (récupération automatique de PostgreSQL vérifiée) ;
un scénario d'audit automatisé ; des pods durcis ; et une documentation qui
explique chaque choix.

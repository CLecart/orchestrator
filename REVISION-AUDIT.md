# Révision de l'audit — orchestrator

Les 33 étapes de la grille officielle, dans l'ordre. Pour chacune : la question
en français, la formulation de la grille en italique, une réponse courte et la
commande qui la prouve. Les explications complètes sont dans le
[README](README.md).

> **Avant de commencer :** le cluster doit tourner. S'il est éteint :
> `./orchestrator.sh start` ; s'il n'existe pas : `./orchestrator.sh create`.
> Passerelle : `http://192.168.56.110:3000`. Contrôle global :
> `./orchestrator.sh status`.

## Sommaire

1. [Général](#général) — étapes 1 à 5
2. [Cluster](#cluster) — étapes 6 à 9
3. [Infrastructure](#infrastructure) — étapes 10 à 12
4. [Manifests](#manifests) — étapes 13 à 15
5. [Secrets](#secrets) — étape 16
6. [Ressources déployées](#ressources-déployées) — étapes 17 à 19
7. [API inventaire](#api-inventaire) — étapes 20 et 21
8. [API facturation](#api-facturation) — étapes 22 à 24
9. [Base de facturation](#base-de-facturation) — étapes 25 à 27
10. [Résilience de la file](#résilience-de-la-file) — étapes 28 et 29
11. [Composants de Kubernetes](#composants-de-kubernetes) — étape 30
12. [Bonus](#bonus) — étapes 31 à 33

---

## Général

### 1. Tous les fichiers demandés sont-ils présents ?

*Are all the required files present?*

**Réponse :** Oui : `README.md`, `orchestrator.sh`, `Vagrantfile`, les
manifests (`Manifests/`), les scripts (`Scripts/`) et les Dockerfiles avec leur
code (`Dockerfiles/`). Les seuls fichiers absents du dépôt sont les Secrets
générés (`Manifests/secrets/*.yaml`), volontairement : ils contiennent les mots
de passe. Leurs modèles `*.yaml.example` sont versionnés.

**Preuve :** `git ls-files | head -40` · `git check-ignore -v Manifests/secrets/billing-db-secret.yaml`

### 2. La structure ressemble-t-elle à celle du sujet ? Sinon, est-elle justifiée ?

*Does the project as a structure similar to the one below? If not, can the student provide a justification for the chosen project structure?*

**Réponse :** Oui : `Manifests/`, `Scripts/`, `Dockerfiles/`, `Vagrantfile`.
Deux précisions : `orchestrator.sh` est à la racine parce que c'est le point
d'entrée appelé par `./orchestrator.sh create` ; `Dockerfiles/` contient aussi
le code source, parce qu'une image se construit depuis un contexte complet.

**Preuve :** `tree -L 2 -I node_modules` (ou `find . -maxdepth 2 -not -path './.git*'`)

### 3. Questions : orchestration, Kubernetes, K3s

*What is container orchestration, and what are its benefits? What is Kubernetes, and what is its main role? What is K3s, and what is its main role?*

**Réponse :**
- **Orchestration** : automatiser le déploiement et la gestion de conteneurs
  sur plusieurs machines à partir d'un état déclaré. Avantages : placement
  automatique, auto-réparation, mise à l'échelle, découverte de services et
  répartition de charge, mises à jour progressives, reproductibilité.
- **Kubernetes** : l'orchestrateur de référence (CNCF). Rôle : faire tourner
  des conteneurs sur un cluster en maintenant en permanence l'état déclaré
  (boucles de réconciliation).
- **K3s** : distribution Kubernetes légère et certifiée (Rancher/SUSE), un seul
  binaire, SQLite au lieu d'etcd, containerd, flannel, CoreDNS, ServiceLB et
  metrics-server inclus. Rôle : un vrai cluster sur des machines modestes.

**Preuve :** README [§17](README.md#17-questions-daudit--réponses-types)

### 4. Le README contient-il toute la documentation ?

*Did the README.md file contains all the required information about the solution (prerequisites, configuration, setup, usage, ...)?*

**Réponse :** Oui : prérequis (§1), configuration (§2), installation (§3),
utilisation (§4), API (§5), scénario d'audit (§6), manifests (§7), secrets,
stockage, autoscaling, cluster, images, sécurité, bonus, dépannage, questions
d'audit, composants de Kubernetes.

**Preuve :** le sommaire du [README](README.md#sommaire)

### 5. Les images des manifests viennent-elles de mon compte Docker Hub ?

*Are the docker images used in the YAML manifest uploaded from the student's Docker Hub account?*

**Réponse :** Oui, les six viennent de `docker.io/clecart` en tag `1.0.0`,
construites depuis mes Dockerfiles et poussées par `./orchestrator.sh push`.

**Preuve :** `grep -h 'image:' Manifests/*.yaml` · <https://hub.docker.com/u/clecart> ·
`kubectl get pods -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'`

---

## Cluster

### 6. kubectl est-il installé et configuré sur ma machine ?

*Is kubectl installed and configured in the learner's machine?*

**Réponse :** Oui : binaire v1.36.4 sur l'hôte, contexte `orchestrator`
installé dans `~/.kube/config` par `orchestrator.sh`.

**Preuve :** `kubectl version` · `kubectl config current-context` → `orchestrator`

### 7. Le cluster a-t-il été créé par un Vagrantfile ?

*Was the cluster created by a Vagrantfile?*

**Réponse :** Oui : le `Vagrantfile` définit les VM `master` et `agent`
(VirtualBox, Ubuntu 24.04) et les provisionne avec `Scripts/k3s-master.sh` et
`Scripts/k3s-agent.sh`.

**Preuve :** `vagrant status` → `master running`, `agent running`

### 8. Le cluster a-t-il deux nœuds (master et agent) ?

*Does the cluster contain two nodes (master and agent)?*

**Réponse :** Oui : `master` (K3s server, rôle `control-plane`) et `agent`
(K3s agent).

**Preuve :** `kubectl get nodes -A -o wide`

### 9. Les nœuds sont-ils connectés et prêts ?

*Are the nodes connected and ready for usage?*

**Réponse :** Oui, les deux sont `Ready`, et des pods tournent sur chacun
(`svclb-api-gateway` est présent sur les deux).

**Preuve :** `kubectl get nodes` · `kubectl get pods -A -o wide`

---

## Infrastructure

### 10. `orchestrator.sh` crée-t-il et gère-t-il l'infrastructure ?

*Did the student provide an `orchestrator.sh` script that runs and creates and manages the infrastructure?*

**Réponse :** Oui : `create` (VM + K3s + kubectl + déploiement → `cluster
created`), `start` (`cluster started`), `stop` (`cluster stopped`), plus
`destroy`, `status`, `deploy`, `undeploy`, `push`, `test`, `load`, `bonus`.

**Preuve :** `./orchestrator.sh help` · `./orchestrator.sh create`

### 11. L'architecture est-elle respectée ?

*Did the student respect the architecture?*

**Réponse :** Oui : passerelle → inventaire (HTTP) → base inventaire ;
passerelle → RabbitMQ (AMQP) → facturation → base facturation ; Secrets ;
volumes des deux bases ; images sur Docker Hub ; manifests appliqués par
kubectl ; cluster créé par Vagrant.

**Preuve :** `kubectl get all` · schéma du README [§0.2](README.md#02-architecture-applicative)

### 12. L'infrastructure a-t-elle démarré correctement ?

*Did the infrastructure start correctly?*

**Réponse :** Oui : 6 pods `Running` et `1/1`, 3 PVC `Bound`, passerelle
`/health` à 200.

**Preuve :** `kubectl get pods` · `kubectl get pvc` · `curl -s http://192.168.56.110:3000/health`

---

## Manifests

### 13. Y a-t-il un manifest YAML par service ?

*Is there a YAML Manifest for each service?*

**Réponse :** Oui : `api-gateway.yaml`, `inventory-app.yaml`,
`inventory-database.yaml`, `billing-app.yaml`, `billing-database.yaml`,
`rabbitmq.yaml`, plus `storage.yaml` (volumes) et `secrets/` (identifiants).

**Preuve :** `ls Manifests/ Manifests/secrets/`

### 14. Aucun identifiant hors des manifests de Secrets ?

*Are credentials not existing in the YAML manifests, except the secret manifests?*

**Réponse :** Oui : les autres manifests ne contiennent que des
`secretKeyRef`. Et même les manifests de Secrets ne sont pas versionnés : ils
sont générés avec des mots de passe aléatoires.

**Preuve :** `grep -rnE 'password|passwd|secret' Manifests/*.yaml | grep -v -E 'secretKeyRef|name: .*-secret|key: password'` → aucune ligne

### 15. Questions : IaC, manifest, chaque manifest

*What is infrastructure as code and what are the advantages of it? Explain what is a K8s manifest. Explain each K8s manifests.*

**Réponse :**
- **IaC** : décrire l'infrastructure dans des fichiers versionnés
  (`Vagrantfile`, scripts, manifests) au lieu de la configurer à la main.
  Reproductible, versionné, relisible, automatisable, sans dérive.
- **Manifest** : fichier YAML décrivant l'état souhaité d'objets Kubernetes
  (`apiVersion`, `kind`, `metadata`, `spec`) ; `kubectl apply` l'envoie à
  l'API et les contrôleurs le réalisent.
- **Chaque manifest** : README [§7](README.md#7-les-manifests-expliqués).

---

## Secrets

### 16. Tous les identifiants utilisés sont-ils dans les Secrets ?

*Are all the used credentials and passwords present in the secrets?*

**Réponse :** Oui : `inventory-db-secret`, `billing-db-secret` et
`rabbitmq-secret`, chacun avec `username` et `password` — les trois comptes de
l'application. Base64 = encodage, pas chiffrement.

**Preuve :** `kubectl get secrets -o json` ·
`kubectl get secret billing-db-secret -o jsonpath='{.data.username}' | base64 -d`

---

## Ressources déployées

### 17. Toutes les applications demandées sont-elles déployées ?

*Are all the required applications deployed?*

**Réponse :** Oui : `inventory-db` (5432), `billing-db` (5432),
`inventory-app` (8080), `billing-app` (8080), `rabbitmq` (5672),
`api-gateway` (3000).

**Preuve :** `kubectl get all`

### 18. Chaque application a-t-elle la bonne configuration ?

*Do all apps deploy with the correct configuration?*

**Réponse :** Oui :
- bases : StatefulSets avec volumes (`kubectl get sts,pvc`) ;
- `api-gateway` et `inventory-app` : Deployments + HPA min 1, max 3, 60 % CPU
  (`kubectl get hpa`) ;
- `billing-app` : StatefulSet (`kubectl get sts billing-app`).

**Preuve :** `kubectl get deploy,sts,hpa,pvc` · démonstration de l'autoscaling :
`./orchestrator.sh load` (1 → 3 réplicas en moins de 30 s)

### 19. Questions : StatefulSet, Deployment, différence, scaling, load balancer, base en Deployment

*What is StatefulSet in K8s? What is deployment in K8s? What is the difference between deployment and StatefulSet in K8s? What is scaling, and why do we use it? What is a load balancer, and what is its role? Why we don't put the database as a deployment?*

**Réponse :**
- **StatefulSet** : pods à identité stable (`billing-db-0`), un volume par pod
  qui le suit, démarrage et arrêt ordonnés. Pour les applications avec état.
- **Deployment** : pods interchangeables (noms aléatoires) gérés par un
  ReplicaSet, mises à jour progressives et retours arrière. Pour les
  applications sans état.
- **Différence** : identité, stockage propre à chaque pod, ordre, DNS par pod
  (Service headless).
- **Scaling** : adapter le nombre de copies (horizontal) ou leurs ressources
  (vertical) à la charge ; tenir les pics, économiser le reste du temps, gagner
  en disponibilité.
- **Load balancer** : point d'entrée unique qui répartit le trafic entre les
  instances saines ; ici le Service `LoadBalancer` de la passerelle (ServiceLB)
  et le Service ClusterIP de l'inventaire.
- **Base en Deployment** : ses pods partageraient un même volume et
  tourneraient à deux pendant une mise à jour → corruption ; une base veut une
  identité et un stockage stables.

**Preuve :** README [§17](README.md#17-questions-daudit--réponses-types)

---

## API inventaire

### 20. `POST /api/movies/` répond-il 200 ?

*Can you confirm the response was the success code 200?*

**Preuve :**

```bash
curl -s -w '\n%{http_code}\n' -X POST http://192.168.56.110:3000/api/movies/ \
  -H 'Content-Type: application/json' \
  -d '{"title":"A new movie","description":"Very short description"}'
```

→ le film créé en JSON, puis `200`.

### 21. `GET /api/movies/` répond-il 200 avec le dernier film en JSON ?

*Can you confirm the response was success code 200 and the body of the response is in json with the information of the last added movie?*

**Preuve :** `curl -s -w '\n%{http_code}\n' http://192.168.56.110:3000/api/movies/` →
liste JSON contenant `"A new movie"`, puis `200`.

---

## API facturation

### 22. `POST /api/billing/` répond-il 200 ?

*Can you confirm the response was success code 200?*

**Preuve :**

```bash
curl -s -w '\n%{http_code}\n' -X POST http://192.168.56.110:3000/api/billing/ \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"20","number_of_items":"99","total_amount":"250"}'
```

→ `{"message":"Message posted"}` puis `200`.

### 23. `billing-app` est-il correctement arrêté ?

*Can you confirm the billing-app container was correctly stopped?*

**Réponse :** On ramène le StatefulSet à 0 réplica (un conteneur tué à la
main serait recréé aussitôt par Kubernetes).

**Preuve :** `kubectl scale statefulset billing-app --replicas=0` puis
`kubectl get sts billing-app` → `0/0` et `kubectl get pods -l app=billing-app` →
`No resources found`.

### 24. `POST /api/billing/` répond-il 200 même sans `billing-app` ?

*Can you confirm the response was success code 200 even if the billing_app is not working?*

**Réponse :** Oui : la passerelle dépose le message dans RabbitMQ, elle ne
parle jamais à `billing-app`.

**Preuve :** le même `curl` avec `{"user_id":"22","number_of_items":"10","total_amount":"50"}` →
`200` ; `kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages` →
`billing_queue 1`.

---

## Base de facturation

### 25. La base `orders` est-elle listée ?

*Can you confirm the `orders` database is listed?*

**Preuve :** `kubectl exec -it pods/billing-db-0 -- sh`, puis `psql`, puis
`\l` → ligne `orders`.

`sudo -i -u postgres` est inutile (et `sudo` n'existe pas dans l'image) : le
conteneur tourne déjà en `postgres` (`whoami`), et `PGUSER`/`PGDATABASE` sont
préremplis, donc `psql` seul suffit.

### 26. La commande de `user_id = 20` est-elle présente ?

*Can you confirm the order with user_id = 20 is listed properly?*

**Preuve :** dans `psql` : `\c orders` puis `TABLE orders;` → ligne `20 | 99 | 250.00`.

### 27. La commande de `user_id = 22` est-elle absente ?

*Can you confirm the order with user_id = 22 is NOT listed?*

**Réponse :** Oui : elle attend dans la file tant que `billing-app` est arrêté.

**Preuve :** `TABLE orders;` → pas de ligne `22`.

---

## Résilience de la file

### 28. `billing-app` redémarre-t-il correctement ?

*Can you confirm the billing-app container was correctly stopped?* (la grille
réutilise la phrase de l'étape 23 ; il s'agit ici du redémarrage)

**Preuve :** `kubectl scale statefulset billing-app --replicas=1` puis
`kubectl rollout status statefulset/billing-app` et `kubectl get pods billing-app-0` → `1/1 Running`.

### 29. La commande de `user_id = 22` est-elle maintenant présente ?

*Can you confirm the order with user_id = 22 is now listed properly?*

**Preuve :** `kubectl exec billing-db-0 -- psql -c 'TABLE orders'` → ligne
`22 | 10 | 50.00` ; `kubectl logs billing-app-0 | grep 'order stored'` ;
file vide (`billing_queue 0`).

Tout le scénario 20 → 29 en une commande : `./orchestrator.sh test` →
`All 14 checks passed`.

---

## Composants de Kubernetes

### 30. Expliquer tous les composants de Kubernetes en moins de 15 minutes

*In less than 15 minutes and with the help of Google the student must explain all Kubernetes components and their roles.*

**Réponse (plan de 5 minutes) :**

- **Plan de contrôle** (le cerveau, sur `master`) :
  - **kube-apiserver** : porte d'entrée unique (6443), authentifie, autorise,
    valide, stocke ; tout le monde ne parle qu'à lui.
  - **etcd** : base clé-valeur de tout l'état du cluster (K3s : SQLite via Kine).
  - **kube-scheduler** : choisit le nœud de chaque nouveau pod.
  - **kube-controller-manager** : les boucles de réconciliation (Deployment,
    ReplicaSet, StatefulSet, nœuds, HPA, volumes…).
  - **cloud-controller-manager** : lien avec un cloud (K3s : adresses des
    nœuds et ServiceLB pour les Services `LoadBalancer`).
- **Nœuds** (les bras, `master` et `agent`) :
  - **kubelet** : démarre les pods assignés via le runtime, monte les volumes,
    exécute les sondes, remonte les états.
  - **kube-proxy** : règles réseau qui font marcher les Services.
  - **container runtime** : containerd, exécute les conteneurs.
- **Addons** : CNI (flannel), DNS (CoreDNS), metrics-server.
- **Trajet d'un `kubectl apply`** : API server → stockage → contrôleur crée
  les pods → scheduler place → kubelet démarre via containerd → kube-proxy
  route.

**Preuve :** `kubectl get pods -n kube-system` · `kubectl get --raw '/readyz?verbose'` ·
`vagrant ssh master -c 'sudo k3s crictl ps'` · README [§18](README.md#18-les-composants-de-kubernetes)

---

## Bonus

### 31. Ma propre solution *play-with-containers* est-elle utilisée ?

*Did the student used his/her own play-with-container solution instead of the provided one?*

**Réponse :** Oui : les six images viennent de mes Dockerfiles (Alpine 3.23,
Node.js 24, PostgreSQL 17, RabbitMQ 4.2, non-root, multi-étapes), recopiés
dans `Dockerfiles/`.

**Preuve :** `ls Dockerfiles/` · `head -20 Dockerfiles/api-gateway/Dockerfile`

### 32. Des bonus optionnels ont-ils été ajoutés ?

*Did the student add any optional bonus?*

**Réponse :** Oui :
- tableau de bord du cluster **Headlamp** (successeur du Kubernetes Dashboard)
  et tableau de bord des journaux **Dozzle** : `./orchestrator.sh bonus` ;
- volumes **NFS** : une base peut changer de nœud sans perdre ses données
  (`kubectl drain agent …`) ;
- **arrêt propre** des nœuds par le kubelet ;
- scénario d'audit automatisé (`test`) et démonstration des HPA (`load`) ;
- pods durcis (non-root, lecture seule, sans capacités, sans jeton d'API).

**Preuve :** `./orchestrator.sh bonus` puis <http://192.168.56.110:4466> et
<http://192.168.56.110:8888>

### 33. Le projet est-il remarquable ?

*Is this project an outstanding project?*

**Réponse :** À l'appréciation de l'auditeur : infrastructure entièrement
reproductible en une commande, aucun secret versionné, stockage réellement
mobile entre nœuds, arrêt propre, tests automatisés, documentation complète.

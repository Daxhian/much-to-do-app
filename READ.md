# MuchToDo — Container Assessment

A containerized deployment of the MuchToDo Golang REST API with MongoDB and Redis, using Docker Compose for local development and Kind (Kubernetes in Docker) for cluster deployment.

## Stack

- **Backend** — Golang (Gin framework), port 8080
- **Database** — MongoDB 8.0 with replica set
- **Cache** — Redis 7.2 (optional, toggled via `ENABLE_CACHE`)
- **Config** — Viper reads from `.env` file at runtime

---

## Project Structure

```
.
├── Dockerfile                          # Multi-stage build (golang:1.25-alpine → alpine:3.19)
├── docker-compose.yml                  # Local dev: backend + MongoDB + Redis
├── .dockerignore
├── .env                                # Your local config (gitignored)
├── mongodb.key                         # MongoDB replica set keyfile (gitignored)
├── cmd/api/                            # Application entrypoint
├── internal/                           # App internals (config, handlers, routes...)
├── kubernetes/
│   ├── namespace.yaml
│   ├── mongodb/
│   │   ├── mongodb-secret.yaml         # Root credentials (base64)
│   │   ├── mongodb-configmap.yaml      # Host and port
│   │   ├── mongodb-pvc.yaml            # 1Gi persistent volume
│   │   ├── mongodb-deployment.yaml
│   │   └── mongodb-service.yaml        # ClusterIP (internal only)
│   ├── backend/
│   │   ├── backend-secret.yaml         # JWT key + Mongo URI
│   │   ├── backend-configmap.yaml      # Non-sensitive env vars
│   │   ├── backend-deployment.yaml     # 2 replicas + init container for .env
│   │   └── backend-service.yaml        # NodePort 30080
│   └── ingress.yaml
└── scripts/
    ├── docker-build.sh
    ├── docker-run.sh
    ├── k8s-deploy.sh
    └── k8s-cleanup.sh
```

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (for Kubernetes phase)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (for Kubernetes phase)
- Make scripts executable: `chmod +x scripts/*.sh`

---

## Phase 1: Docker Compose (Local Development)

### 1. Generate the MongoDB keyfile (one time only)

MongoDB runs as a replica set, which requires a keyfile for internal auth:

```bash
openssl rand -base64 756 > mongodb.key
sudo chown 999:999 mongodb.key
chmod 400 mongodb.key
```

### 2. Create your `.env` file

```bash
nano .env
```

Paste the following and save:

```env
PORT=8080
MONGO_HOST=mongodb
MONGO_PORT=27017
MONGO_INITDB_ROOT_USERNAME=root
MONGO_INITDB_ROOT_PASSWORD=rootpassword
DB_NAME=much_todo_db
MONGO_URI=mongodb://root:rootpassword@mongodb:27017/much_todo_db?authSource=admin&replicaSet=rs0&directConnection=true
JWT_SECRET_KEY=local-dev-secret-change-in-production
JWT_EXPIRATION_HOURS=72
REDIS_HOST=redis
REDIS_PORT=6379
ENABLE_CACHE=true
REDIS_ADDR=redis:6379
REDIS_PASSWORD=
LOG_LEVEL=DEBUG
LOG_FORMAT=text
```

> **Why `.env` is needed:** The app uses Viper to load config, which reads a `.env` file from the working directory. A volume mount injects it into the container at `/app/.env` at runtime — it is never baked into the image.

### 3. Start all services

```bash
docker compose -f docker-compose.yml up -d
```

Or using the script:
```bash
./scripts/docker-run.sh
```

### 4. Verify

```bash
# Health check
curl http://localhost:8080/ping
# → {"message":"pong"}

# Swagger UI (interactive API explorer)
open http://localhost:8080/swagger/index.html
```

### 5. Test the API

**Register a user:**
```bash
curl -X POST http://localhost:8080/api/v1/users/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "test@example.com", "password": "Password123!"}'
```

**Login:**
```bash
curl -X POST http://localhost:8080/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "Password123!"}'
```

**Create a todo (use token from login response):**
```bash
curl -X POST http://localhost:8080/api/v1/todos \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"title": "My first todo", "description": "Testing the API"}'
```

### Useful commands

```bash
docker compose logs -f backend        # Stream backend logs
docker compose logs -f mongodb        # Stream MongoDB logs
docker compose ps                     # Check service status
docker compose down                   # Stop all services
docker compose down -v                # Stop and wipe all volumes (resets DB)
```

---

## Phase 2: Kubernetes with Kind

### Deploy with one command

```bash
./scripts/k8s-deploy.sh
```

This script:
1. Creates a Kind cluster named `muchtodo-cluster`
2. Builds the backend Docker image
3. Loads the image into Kind (no registry needed)
4. Installs the nginx ingress controller
5. Applies all manifests in the correct order
6. Waits for all pods to become ready

### Access the application

**Via NodePort:**
```bash
curl http://localhost:30080/ping
```

**Via Ingress** — add this to `/etc/hosts` first:
```
127.0.0.1 muchtodo.local
```
Then:
```bash
curl http://muchtodo.local/ping
```

### Useful kubectl commands

```bash
# Pod status
kubectl get pods -n muchtodo

# Services
kubectl get services -n muchtodo

# Ingress
kubectl get ingress -n muchtodo

# Backend logs
kubectl logs -n muchtodo -l app=backend -f

# Describe a pod (useful for debugging CrashLoopBackOff etc.)
kubectl describe pod -n muchtodo -l app=backend

# Check all resources in namespace
kubectl get all -n muchtodo
```

### Cleanup

```bash
./scripts/k8s-cleanup.sh
```

---

## Key Design Decisions

### Why an init container in Kubernetes?
Viper's `Unmarshal()` doesn't read Kubernetes-injected environment variables directly — it needs a physical `.env` file. The init container runs before the main container, writes all ConfigMap and Secret values into a `.env` file on a shared volume, and the backend container reads that file via a volume mount at `/app/.env`.

### Why a replica set for MongoDB?
The original app was designed with MongoDB transactions and change streams in mind, both of which require a replica set. Running standalone MongoDB would cause connection errors.

### Why `imagePullPolicy: Never` in Kubernetes?
Kind runs a local cluster — there's no image registry. Images must be loaded directly into the cluster with `kind load docker-image`. Setting `Never` tells Kubernetes to use what's already loaded rather than trying to pull from Docker Hub.

---

## Environment Variables Reference

| Variable | Description | Default |
|---|---|---|
| `PORT` | API server port | `8080` |
| `MONGO_URI` | Full MongoDB connection string | required |
| `DB_NAME` | MongoDB database name | `much_todo_db` |
| `JWT_SECRET_KEY` | Secret for signing JWT tokens | required |
| `JWT_EXPIRATION_HOURS` | Token validity in hours | `72` |
| `ENABLE_CACHE` | Enable Redis caching | `false` |
| `REDIS_ADDR` | Redis address | `localhost:6379` |
| `REDIS_PASSWORD` | Redis password | `""` |
| `LOG_LEVEL` | DEBUG / INFO / WARN / ERROR | `INFO` |
| `LOG_FORMAT` | `json` or `text` | `json` |
# 專案 Fork 來源
本專案 Fork 自：<https://github.com/dayan888/springdemo_k8s>

# springdemo_k8s（中文說明）

此專案為 Spring Boot + Kubernetes 的 Todo Web 示範系統，目標是提供一套可在本機與 GKE 佈署的完整樣板，包含 Web、應用程式、資料庫、Redis、儲存與觀測能力。

## 1. 功能與重點

- 基本功能：登入驗證、Todo CRUD、圖片上傳。
- 應用程式：Spring Boot（內嵌 Tomcat）。
- Web：Nginx 反向代理。
- 資料層：PostgreSQL + Redis Session。
- 儲存：PVC / NFS，並加入 NFS CSI 使用方式。
- 觀測：Prometheus metrics + OpenTelemetry Java Agent。
- 流量入口：支援 Ingress（含 TLS）。

## 2. 專案目錄

- `src/`：Spring Boot 程式碼與模板。
- `deploy/`：Dockerfile、K8s manifests、快速佈署腳本。
- `deploy/app/`：apserver 佈署與 ServiceMonitor。
- `deploy/lb/`：Ingress / NodePort / LoadBalancer 設定。
- `deploy/nfs/`：NFS 與 NFS CSI 相關設定與指引。
- `deploy/sh/`：`local.sh`、`gke.sh` 自動化佈署腳本。

## 3. 執行需求

- JDK 8+
- Docker
- Kubernetes 叢集（minikube / Docker Desktop / GKE）
- kubectl
- （本機開發）PostgreSQL、Redis

## 4. 本機開發（不走 Kubernetes）

1. 建置：

```bash
./gradlew build -x test
```

2. 啟動：

```bash
java -jar build/libs/springdemo-0.5.0.jar
```

3. 開啟：`http://localhost:8080/login`

預設帳號：
- ID：`admin`
- PW：`111111`

## 5. Docker 建置

建議先定義統一映像前綴（以下以 shell 範例）：

```bash
export IMAGE_PREFIX=YOUR_REGISTRY/YOUR_NAMESPACE/springdemo
```

### 5.1 App 映像

```bash
./gradlew build -x test
docker image build -t ${IMAGE_PREFIX}-apserver:latest -f deploy/app/Dockerfile .
```

### 5.2 Web 映像

```bash
docker image build -t ${IMAGE_PREFIX}-web:latest -f deploy/web/Dockerfile .
```

### 5.3 DB 映像

```bash
docker image build -t ${IMAGE_PREFIX}-db:latest -f deploy/db/Dockerfile .
```

### 5.4 推送映像（可選）

```bash
docker push ${IMAGE_PREFIX}-apserver:latest
docker push ${IMAGE_PREFIX}-web:latest
docker push ${IMAGE_PREFIX}-db:latest
```

### 5.5 同步更新 K8s manifest 的 image

目前專案內的 manifests 仍含示範 image 名稱（如 `isaac0815/...`、`dayan888/...`），建議以同一前綴統一替換。

```bash
# 先備份
cp -r deploy deploy.bak

# Linux (GNU sed)
find deploy -name "*.yaml" -type f \
  -exec sed -i -e "s#isaac0815/apserver:latest#${IMAGE_PREFIX}-apserver:latest#g" \
               -e "s#isaac0815/nginx:latest#${IMAGE_PREFIX}-web:latest#g" \
               -e "s#isaac0815/db:latest#${IMAGE_PREFIX}-db:latest#g" \
               -e "s#dayan888/springdemo:apserver#${IMAGE_PREFIX}-apserver:latest#g" \
               -e "s#dayan888/springdemo:nginx#${IMAGE_PREFIX}-web:latest#g" \
               -e "s#dayan888/springdemo:postgres9.6#${IMAGE_PREFIX}-db:latest#g" {} +

# macOS (BSD sed)
find deploy -name "*.yaml" -type f \
  -exec sed -i '' -e "s#isaac0815/apserver:latest#${IMAGE_PREFIX}-apserver:latest#g" \
                  -e "s#isaac0815/nginx:latest#${IMAGE_PREFIX}-web:latest#g" \
                  -e "s#isaac0815/db:latest#${IMAGE_PREFIX}-db:latest#g" \
                  -e "s#dayan888/springdemo:apserver#${IMAGE_PREFIX}-apserver:latest#g" \
                  -e "s#dayan888/springdemo:nginx#${IMAGE_PREFIX}-web:latest#g" \
                  -e "s#dayan888/springdemo:postgres9.6#${IMAGE_PREFIX}-db:latest#g" {} +
```

> Windows（PowerShell）環境建議改用 VS Code 全域取代或 `Get-ChildItem` + `-replace` 方式處理。

## 6. Kubernetes 佈署

### 6.1 快速佈署腳本

- 本機：`deploy/sh/local.sh`
- GKE：`deploy/sh/gke.sh`

> 注意：腳本中的 `open`、`stern` 等指令依作業系統可能需要調整。

### 6.2 建議手動佈署順序

1. redis
2. db
3. nfs（GKE / 需要 RWX 時）
4. app
5. web
6. ingress 或 loadbalancer

## 7. Prometheus 監控

此專案已加入 Prometheus 指標輸出與 K8s 抓取設定。

- Gradle 依賴：
  - `spring-boot-starter-actuator`
  - `micrometer-registry-prometheus`
- 指標路徑：`/actuator/prometheus`
- 安全設定已放行該路徑：`src/main/java/net/in/dayan/springdemo/common/WebConfig.java`
- ServiceMonitor 檔案：`deploy/app/todoweb-service-monitor.yaml`
  - namespace：`monitoring`
  - 監控目標 namespace：`todoweb`
  - endpoint path：`/actuator/prometheus`
  - port name：`http-port`

## 8. OpenTelemetry 追蹤

此專案已加入 OpenTelemetry Java Agent。

- Dockerfile：`deploy/app/Dockerfile`
  - 複製 `build/libs/opentelemetry-javaagent.jar` 到容器
  - 以 `-javaagent:/app/opentelemetry-javaagent.jar` 啟動
- K8s 部署環境變數（`deploy/app/deployment.yaml`）：
  - `OTEL_EXPORTER_OTLP_ENDPOINT=http://simplest-collector.default:4318`
  - `OTEL_RESOURCE_ATTRIBUTES=service.name=demoweb`

建議：若 Collector 或 Backend 不在 `default` namespace，請調整 endpoint。

## 9. Ingress 設定

Ingress 設定檔：`deploy/lb/ingress.yaml`

使用 Ingress 前，建議先完成 TLS secret 建立：

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ~/tls.key -out ~/tls.crt -subj "/CN=sbdemo.example.com"
kubectl create secret tls --save-config tls-sbdemo --key ~/tls.key --cert ~/tls.crt

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ~/tls.key -out ~/tls.crt -subj "/CN=grafana.example.com"
kubectl create secret tls --save-config tls-grafana --key ~/tls.key --cert ~/tls.crt
```

另外，多數叢集不只一種 Ingress Controller（不一定預設是 nginx），請在 `deploy/lb/ingress.yaml` 指定 `ingressClassName`，例如：

```yaml
spec:
  ingressClassName: nginx
```

- API：`networking.k8s.io/v1`
- host：`sbdemo.example.com`
- `/` 轉發至 `sbdemo-nginx-np:80`
- `/v2/` 轉發至 `web2:8080`
- TLS secret：`tls-sbdemo`

搭配檔案：
- `deploy/lb/nodeport.yaml`
- `deploy/lb/loadbalancer.yaml`

## 10. NFS 與 NFS CSI

### 10.1 NFS（既有方式）

- `deploy/nfs/nfs-server.yaml`
- `deploy/nfs/nfs-server-service.yaml`
- `deploy/nfs/nfs-pv.yaml`
- `deploy/nfs/nfs-pvc.yaml`
- `deploy/nfs/nfs-server-gke-pv.yaml`

### 10.2 NFS CSI（新增）

說明文件：`deploy/nfs/create csi-nfs-sc.txt`

包含：
- 安裝 `csi-driver-nfs`
- 建立 `nfs-csi-todoweb` StorageClass 的範例

目前 manifests 也已使用 CSI StorageClass，例如：
- App PVC：`deploy/app/pvc.yaml` 使用 `storageClassName: nfs-csi`
- DB StatefulSet：`deploy/db/statefulset.yaml` 的 volumeClaimTemplates 使用 `storageClassName: nfs-csi`

請依叢集實際 StorageClass 名稱統一（例如 `nfs-csi` 或 `nfs-csi-todoweb`）。

## 11. 重要設定提醒

- 預設帳密與明文密碼僅供示範，請勿直接用於正式環境。
- 請依環境調整映像名稱（目前部分 manifest 仍是示範 registry）。
- 若使用 Ingress + TLS，自簽憑證在瀏覽器會需要手動信任。
- 若 Prometheus 沒抓到指標，先確認：
  1. `todoweb-service-monitor.yaml` 是否已套用
  2. Prometheus Operator 是否存在
  3. Service label、port name、namespace 是否一致

## 12. 參考指令

```bash
# 觀察資源
kubectl get pods -n todoweb
kubectl get svc -n todoweb
kubectl get ing -n todoweb

# 套用 app 相關
kubectl apply -f deploy/app/deployment.yaml
kubectl apply -f deploy/app/service.yaml
kubectl apply -f deploy/app/todoweb-service-monitor.yaml
```

## 13. 授權

本專案使用 MIT License，詳見 `LICENSE`。
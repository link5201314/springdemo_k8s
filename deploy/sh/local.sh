# Spring Boot demo application for Kubernetes

# For Local environmnet

echo "Creating Spring Boot demo application for Kubernetes on local environment"

### Create configmap for nginx
kubectl create configmap nginx-conf --from-file=deploy/web/nginx.conf -n todoweb 
kubectl create configmap server-conf --from-file=deploy/web/server.conf -n todoweb

### Create deployments and services
echo "Create deployments and services"
# redis
kubectl apply -f deploy/redis/deployment.yaml
kubectl apply -f deploy/redis/service.yaml

# db
#kubectl apply -f deploy/db/pv.yaml
kubectl apply -f deploy/db/statefulset.yaml
kubectl apply -f deploy/db/service.yaml

# apserver (For Local environment)
kubectl apply -f deploy/app/pvc.yaml
kubectl apply -f deploy/app/deployment.yaml
kubectl apply -f deploy/app/service.yaml

# web
kubectl apply -f deploy/web/deployment.yaml
kubectl apply -f deploy/web/service.yaml

# LB
#kubectl apply -f deploy/lb/loadbalancer.yaml

#Ingress
kubectl apply -f deploy/lb/nodeport.yaml
kubectl apply -f deploy/lb/ingress.yaml

CTX=$(kubectl config current-context)
echo ${CTX}

if [ "${CTX}" == "minikube" ]; then
    while true; do
        URL=$(minikube service sbdemo-nginx-lb --url)
        echo ${URL}
        if [ "${URL}" == "" ]; then
            sleep 1
        else
            break;
        fi
    done
else
    URL="http://localhost"
fi

# Open browser (if failed, open manually)
echo "open browser for ${URL}/login"
open ${URL}/login

# Log (stern must be installed)
stern -l app=sbdemo-apserver

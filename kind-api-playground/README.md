# KinD API Playground

Following [this](https://martinheinz.dev/blog/73) and making notes.

## Check and see where you are with KinD

```bash
kind version
kind get clusters
```

## Create The KinD Config The Cluster

```bash
# kind.yaml
# https://kind.sigs.k8s.io/docs/user/configuration/
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: api-playground
nodes:
- role: control-plane
- role: worker
```

Don't know if it is necessary to create three worker nodes. One might be enough

## Create The Cluster

```bash
kind create cluster --image kindest/node:v1.29.2 --config=kind.yaml

```

## Create The Service Account

You can reference the docs on creating a token [here](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/).

After you create a Service Account, you need to request a token for the Service Account. There is a binding between the service account and the token. We are going to export the token to an environment variable so we can use it in the cURL command.

```bash
k create serviceaccount pytest
export KIND_TOKEN=$(k create token pytest)
echo $KIND_TOKEN
```

## Get The API Port

If you are running KinD, you can find the api server by looking at docker and running `docker ps`:

```bash
docker ps

f755ad96bb55   kindest/node:v1.29.2   "/usr/local/bin/entr…"   4 minutes ago    Up 4 minutes    127.0.0.1:62287->6443/tcp   kind-api-playground-control-plane

```

Here, you will see the port mapping is `127.0.0.1:62287->6443/tcp`.

The port `62287` can now be used in the curl command:

```bash
curl -k -X GET -H "Authorization: Bearer $KIND_TOKEN" https://127.0.0.1:62287/apis

```

If the command is successful, you will see a lot of JSON output. This is all of the API resources. If you see a different output, you may have to troubleshoot the cURL command.

Let's try to deploy a pod:

```bash
k run nginx --image=nginx

pod/nginx created
```

You should see the pod running:

```bash
k get pods

NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          27s
```

To translate some of the basic `kubectl` commands into something that can be used in cURL run something like:

```bash
kubectl get pods -v 10 -n default

```

The output will splash a lot on the screen, but you should see something like `https://127.0.0.1:62287/api/v1/namespaces/default/pods?limit=500`. You can then take that and use in a cURL command like the following:

```bash
curl -k -X GET -H "Authorization: Bearer $KIND_TOKEN" https://127.0.0.1:62287/api/v1/namespaces/default/pods
```

If you run this, you will get a 403. The response will look something like this:

```json
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:default:pytest\" cannot list resource \"pods\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
}% 
```

This should make sense since we have not give the previously created service account `pytest` and roles or rolebindings. Let's do that now

```bash
k create clusterrole manage-pods \
    --verb=get --verb=list --verb=watch --verb=create --verb=update --verb=patch --verb=delete \
    --resource=pods

k -n default create rolebinding sa-manage-pods \
    --clusterrole=manage-pods \
    --serviceaccount=default:pytest
```

Now you can run the previous cURL command to get pods:

```bash
curl -k -X GET -H "Authorization: Bearer $KIND_TOKEN" https://127.0.0.1:62287/api/v1/namespaces/default/pods
```

For development, let's broaden the scope by giving the service account an admin role:

```bash
kubectl create clusterrolebinding sa-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=default:pytest
```

We can now do something like this:

```bash
curl -k -X GET -H "Authorization: Bearer $KIND_TOKEN" https://127.0.0.1:62743/api/v1/namespaces/default/services
```

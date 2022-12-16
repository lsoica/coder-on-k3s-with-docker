# Expose host docker socket
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dind
  namespace: default
spec:
  containers:
    - name: someconainter
      image: centos
      imagePullPolicy: Always
      tty: true
      command:
        - cat
      volumeMounts: 
        - mountPath: /var/run 
          name: docker-sock 
  volumes:
    - name: docker-sock 
      hostPath: 
          path: /var/run 
```
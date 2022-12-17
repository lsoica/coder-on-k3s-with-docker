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

# Open points
 - Delete button only works when ctrl+click
 - User variables: e.g. docker registry auth
 - custom namespace per workspace with limited RBAC
 - CA cert: cant use the mount as the startup script kicks in first???
 - git clone: not working
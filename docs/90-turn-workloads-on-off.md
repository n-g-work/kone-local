# Turn On/Off

This action prepares VM for poweroff and restores workloads after boot.

```sh
# set the state to 0 and run the commands to prepare the platform for poweroff the VM
# set the state to 1 and run the commands after booting the VM
state=1

for ns in 'kube-system' 'ingress-nginx' 'kubernetes-dashboard'; do echo -e "\n===\nns: ${ns}"; \
  for r in 'deployment' 'statefulset'; do echo -e "---\n${r}s:"; 
    for d in $(kubectl get "${r}" -n "${ns}" -o name); do kubectl scale -n "${ns}" "${d}" --replicas=${state}; done; \
  done; \
done

for ns in 'kube-observable'; do echo -e "\n===\nns: ${ns}"; \
  for r in 'deployment' 'statefulset'; do echo -e "---\n${r}s:"; 
    for d in $(kubectl get "${r}" -n "${ns}" -o name); do kubectl scale -n "${ns}" "${d}" --replicas=${state}; done; \
  done; \
done

kubectl get pod -A --watch
```

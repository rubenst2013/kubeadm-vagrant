require_relative 'vars'

# Generate backends for HA Kubernetes API server
def gen_haproxy_master_backend(master_count)
    server=""
    (1..master_count).each do |i|
      ip = $NODE_IP_NW + "#{i + 10}"
      server << "    server apiserver#{i} #{ip}:6443 check\n"
    end
    server
end


# Generate backends for ingress controllers on worker nodes
def gen_haproxy_worker_backend(node_count)
  server=""
  (1..node_count).each do |i|
    ip = $NODE_IP_NW + "#{i + 20}"
    server << "    server ingress-controller#{i} #{ip}:80 check\n"
  end
  server
end


# Generate backends for public facing load balancer
def gen_haproxy_lb_backend(node_count, backend_port)
  server=""
  (1..load_balancer_count).each do |i|
    ip = $NODE_IP_NW + "#{i + 20}"
    server << "    server node#{i} #{ip}:#{backend_port} check\n"
  end
  server
end
require_relative 'vars'

def gen_haproxy_backend(master_count)
    server=""
    (1..master_count).each do |i|
      ip = $NODE_IP_NW + "#{i + 10}"
      server << "    server apiserver#{i} #{ip}:6443 check\n"
    end
    server
end
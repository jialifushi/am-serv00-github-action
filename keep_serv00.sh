#!/bin/bash

# 定义颜色代码
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
purple() { echo -e "\033[35m$1\033[0m"; }
re="\033[0m"

# 打印欢迎信息
echo ""
purple "=== serv00 | 科技 一键保活脚本 ===\n"
echo -e "${green}脚本地址：${re}${yellow}https://github.com/jialifushi/am-serv00-github-action${re}\n"
echo -e "${green}YouTube频道：${re}${yellow}https://youtube.com/@HertzHe-m6o${re}\n"
echo -e "${green}个人博客：${re}${yellow}https://store.superspace.us.kg/${re}\n"
echo -e "${green}TG反馈群组：${re}${yellow}https://t.me/_CLUBS${re}\n"
purple "=== 转载请著名出处 科技，请勿滥用 ===\n"

base_url="https://raw.githubusercontent.com/amclubs"

# 发送 Telegram 消息的函数
send_telegram_message() {
    local message="$1"
    response=$(curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$message")

    if [[ $(echo "$response" | jq -r '.ok') == "true" ]]; then
        echo "::info::Telegram消息发送成功: $message"
    else
        echo "::error::Telegram消息发送失败: $response"
    fi
}

# 检查是否传入了参数
if [ "$#" -lt 1 ]; then
    echo "用法: $0 <servers.json> [<TG_TOKEN> <CHAT_ID>]"
    echo "请确保将账户信息以 JSON 格式保存在指定的文件中。"
    exit 1
fi

servers_json=$(<"$1")
declare -A servers
TG_TOKEN="$2"
CHAT_ID="$3"

while IFS= read -r line; do
    key=$(echo "$line" | jq -r '.key')
    value=$(echo "$line" | jq -r '.value')
    if [[ -n "$key" && -n "$value" ]]; then
        key=$(echo "$key" | tr -d '"')
        value=$(echo "$value" | tr -d '"')
        IFS=',' read -r domain username password <<< "$key"
        servers["$domain,$username,$password"]="$value"
    fi
done <<< "$(echo "$servers_json" | jq -c 'to_entries | .[] | {key: .key, value: .value}')"

max_fail=3

get_script_url() {
    case $1 in
        s5) echo "${base_url}/am-serv00-socks5/main/am_restart_s5.sh" ;;
        vmess) echo "${base_url}/am-serv00-vmess/main/am_restart_vmess.sh" ;;
        nezha-dashboard) echo "${base_url}/am-serv00-nezha/main/am_restart_dashboard.sh" ;;
        nezha-agent) echo "${base_url}/am-serv00-nezha/main/am_restart_agent.sh" ;;
        x-ui) echo "${base_url}/am-serv00-x-ui/main/am_restart_x_ui.sh" ;;
        *) echo "${base_url}/am-serv00-socks5/main/am_restart_s5.sh" ;;
    esac
}

check_port() {
    nc -zv "$1" "$2" >/dev/null 2>&1
}

check_argo() {
    local http_code
    http_code=$(curl -o /dev/null -s -w "%{http_code}" "https://$1")
    if [ "$http_code" -eq 404 ]; then
        return 0  
    else
        return 1  
    fi
}

execute_remote_script() {
    local script_url token=""
    script_url=$(get_script_url "$4")

    if [[ "$4" == "vmess" ]]; then
        token="${5}"  
    fi

    local ssh_command="$2@$1"  
    if [ -n "$TG_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        send_telegram_message "🔴服务正在重启: $server 用户名: $username 端口: $port 服务: $service"
    fi
    
    if ! sshpass -p "$3" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -tt "$ssh_command" "bash <(curl -Ls $script_url) $token"; then
        if [ -n "$TG_TOKEN" ] && [ -n "$CHAT_ID" ]; then
            send_telegram_message "🔴服务重启失败: $server 用户名: $username 端口: $port 服务: $service"
        fi
    else
        if [ -n "$TG_TOKEN" ] && [ -n "$CHAT_ID" ]; then
            send_telegram_message "🟢服务重启成功: $server 用户名: $username 端口: $port 服务: $service"
        fi
    fi
}

print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${re}"
}

for server_info in "${!servers[@]}"; do
    IFS=',' read -r server username password <<< "$server_info"
    services=${servers[$server_info]}

    IFS=';' read -r -a service_array <<< "$services"

    for service_info in "${service_array[@]}"; do
        IFS=',' read -r service port argo_domain token <<< "$service_info"

        print_status "$re" "检测服务器: $server 用户名: $username 端口: $port 服务: $service ..."

        fail_count=0
        for attempt in {1..3}; do
            if check_port "$server" "$port"; then
                print_status "$green" "端口 $port 在 $server 正常"
                if [ -n "$TG_TOKEN" ] && [ -n "$CHAT_ID" ]; then
                    send_telegram_message "✅ 成功登录到服务。"
                    send_telegram_message "💻 主机名：s14"
                    send_telegram_message "🕰 定时报告：@hourly"
                    send_telegram_message "🟢 端口检测成功: $server 用户名: $username 端口: $port 服务: $service"
                    send_telegram_message "🌐 <$service>服务正常 📡 <$port>端口正常"
                fi
                break
            else
                fail_count=$((fail_count + 1))
                print_status "$red" "第 $attempt 次检测失败，端口 $port 不通"
                sleep 5
            fi
        done

        if [[ "$service" == "vmess" ]]; then
            argo_fail_count=0
            print_status "$re" "开始检测 Argo 隧道..."
            for argo_attempt in {1..3}; do
                if check_argo "$argo_domain"; then
                    print_status "$green" "Argo 隧道在线"
                    if [ -n "$TG_TOKEN" ] && [ -n "$CHAT_ID" ]; then
                        send_telegram_message "✅ 成功登录到服务。"
                        send_telegram_message "💻 主机名：s14"
                        send_telegram_message "🕰 定时报告：@hourly"
                        send_telegram_message "🟢Argo 隧道检测成功: $server 用户名: $username 域名: $argo_domain 服务: $service"
                        send_telegram_message "🌐 <$service>服务正常 📡 <$port>端口正常"
                    fi
                    break
                else
                    argo_fail_count=$((argo_fail_count + 1))
                    print_status "$red" "第 $argo_attempt 次检测 Argo 隧道失败"
                    sleep 5
                fi
            done
        fi

        if [[ $fail_count -eq $max_fail ]] || [[ "$service" == "vmess" && $argo_fail_count -eq $max_fail ]]; then
            print_status "$red" "检测失败，执行重启操作..."
            execute_remote_script "$server" "$username" "$password" "$service" "$token"
        else
            print_status "$re" "检测成功"
        fi

        echo "----------------------------"
    done
done

print_status "$re" "所有服务器检测完毕"

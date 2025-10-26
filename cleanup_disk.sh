#!/bin/bash

# 磁盘清理脚本
# 作者: 系统管理员
# 描述: 用于清理Linux系统磁盘空间，特别针对Docker环境优化

set -e  # 遇到错误退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要root权限运行"
        exit 1
    fi
}

# 显示当前磁盘使用情况
show_disk_usage() {
    log "当前磁盘使用情况:"
    df -h /
    echo ""
}

# 备份重要Docker数据
backup_docker_data() {
    log "检查Docker数据备份..."
    if command -v docker &> /dev/null; then
        local backup_dir="/tmp/docker_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        # 备份重要的Docker配置和数据
        if [ -d "/var/lib/docker/volumes" ]; then
            cp -r /var/lib/docker/volumes "$backup_dir/" 2>/dev/null || true
        fi
        
        log "Docker数据已备份到: $backup_dir"
    fi
}

# 查找所有Docker Compose项目目录
find_docker_compose_projects() {
    local compose_dirs=()
    
    # 查找包含docker-compose.yml或docker-compose.yaml文件的目录
    while IFS= read -r -d '' dir; do
        compose_dirs+=("$dir")
    done < <(find / -name "docker-compose.yml" -o -name "docker-compose.yaml" -exec dirname {} \; 2>/dev/null | sort -u | tr '\n' '\0')
    
    echo "${compose_dirs[@]}"
}

# 停止所有Docker Compose项目
stop_docker_compose_projects() {
    local compose_dirs=($(find_docker_compose_projects))
    
    if [ ${#compose_dirs[@]} -eq 0 ]; then
        warn "未找到Docker Compose项目"
        return
    fi
    
    log "找到 ${#compose_dirs[@]} 个Docker Compose项目，正在停止..."
    
    for dir in "${compose_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "停止项目: $dir"
            cd "$dir" && docker-compose down 2>/dev/null || true
        fi
    done
}

# 重启所有Docker Compose项目
restart_docker_compose_projects() {
    local compose_dirs=($(find_docker_compose_projects))
    
    if [ ${#compose_dirs[@]} -eq 0 ]; then
        warn "未找到Docker Compose项目"
        return
    fi
    
    log "重启 ${#compose_dirs[@]} 个Docker Compose项目..."
    
    for dir in "${compose_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "启动项目: $dir"
            cd "$dir" && docker-compose up -d 2>/dev/null || true
        fi
    done
}

# Docker清理
clean_docker() {
    if command -v docker &> /dev/null; then
        log "开始Docker清理..."
        
        # 先停止所有Docker Compose项目
        stop_docker_compose_projects
        
        # 停止所有运行中的容器
        docker stop $(docker ps -q) 2>/dev/null || true
        
        # 清理无用的资源
        log "清理无用的Docker镜像、容器和网络..."
        docker system prune -a -f
        
        log "清理Docker卷..."
        docker volume prune -f
        
        # 清理Docker日志
        log "清理Docker容器日志..."
        find /var/lib/docker/containers -name "*.log" -size +10M -exec truncate -s 0 {} \;
        
        log "Docker清理完成"
    else
        warn "Docker未安装，跳过Docker清理"
    fi
}

# 系统日志清理
clean_logs() {
    log "开始系统日志清理..."
    
    # 清理journal日志（保留最近7天）
    if command -v journalctl &> /dev/null; then
        journalctl --vacuum-time=7d
    fi
    
    # 清理大日志文件
    find /var/log -name "*.log" -size +50M -exec ls -lh {} \; 2>/dev/null | head -10
    
    read -p "是否要清空这些大日志文件？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find /var/log -name "*.log" -size +50M -exec truncate -s 0 {} \;
    fi
    
    log "系统日志清理完成"
}

# 包缓存清理
clean_package_cache() {
    log "开始包缓存清理..."
    
    if command -v apt-get &> /dev/null; then
        apt-get clean
        apt-get autoremove -y
    elif command -v yum &> /dev/null; then
        yum clean all
        yum autoremove -y
    fi
    
    log "包缓存清理完成"
}

# 临时文件清理
clean_temp_files() {
    log "开始临时文件清理..."
    
    # 清理系统临时文件
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    # 清理用户缓存
    rm -rf /home/*/.cache/* 2>/dev/null || true
    rm -rf /root/.cache/* 2>/dev/null || true
    
    log "临时文件清理完成"
}

# 查找并提示大文件
find_large_files() {
    log "查找大文件（大于100MB）..."
    echo "前10个大文件:"
    find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -rh -k5 | head -10
    
    echo ""
    warn "请手动检查这些大文件，确认是否可以删除"
}

# 主函数
main() {
    log "开始磁盘清理操作"
    check_root
    
    # 显示初始状态
    show_disk_usage
    
    # 备份
    backup_docker_data
    
    # 执行清理操作
    clean_docker
    clean_logs
    clean_package_cache
    clean_temp_files
    
    # 重启所有Docker Compose项目
    restart_docker_compose_projects
    
    # 显示最终状态
    log "清理操作完成，最终磁盘使用情况:"
    show_disk_usage
    
    # 显示大文件信息
    find_large_files
    
    log "磁盘清理脚本执行完毕"
}

# 执行提示
echo "=================================================="
echo "            Linux 磁盘清理脚本"
echo "=================================================="
echo "此脚本将执行以下操作："
echo "1. Docker系统清理（镜像、容器、卷、日志）"
echo "2. 系统日志清理"
echo "3. 包缓存清理"
echo "4. 临时文件清理"
echo "5. 大文件查找"
echo "6. 自动重启所有Docker Compose项目"
echo ""
echo "注意：操作可能需要一些时间，请耐心等待"
echo "=================================================="

read -p "是否继续执行？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    main
else
    log "用户取消操作"
    exit 0
fi

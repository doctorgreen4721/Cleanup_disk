#!/bin/bash

# 设置颜色提示
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'  # 重置颜色

# 输出清理前的磁盘使用情况
echo -e "${GREEN}========================= 磁盘清理前 =========================${NC}"
df -h  # 输出磁盘使用情况

# 清理系统日志
echo -e "${YELLOW}正在清理系统日志...${NC}"
journalctl --vacuum-time=7d  # 清除7天之前的日志

# 清理APT包缓存
echo -e "${YELLOW}正在清理APT包缓存...${NC}"
apt-get clean  # 清除包缓存

# 删除未使用的包
echo -e "${YELLOW}正在删除未使用的包...${NC}"
apt-get autoremove -y  # 自动删除不再需要的包

# 清理临时文件
echo -e "${YELLOW}正在清理临时文件...${NC}"
rm -rf /tmp/*  # 删除临时文件夹下的所有文件
rm -rf /var/tmp/*  # 删除临时文件夹下的所有文件

# 清理Docker日志和容器
echo -e "${YELLOW}正在清理Docker日志和容器...${NC}"

# 删除所有已停止的容器
echo -e "${YELLOW}删除所有已停止的容器...${NC}"
docker container prune -f  # 删除未运行的容器

# 清理正在运行的容器的日志和临时文件
echo -e "${YELLOW}清理正在运行的容器日志...${NC}"
docker ps -q | while read container_id; do
  docker exec -t $container_id sh -c 'echo "" > /var/log/*'  # 清空容器内日志文件
done

# 删除所有未使用的镜像和卷
echo -e "${YELLOW}删除未使用的镜像和卷...${NC}"
docker system prune -a -f  # 删除所有未使用的镜像、容器、卷和网络

# 清理Docker卷
echo -e "${YELLOW}清理Docker卷...${NC}"
docker volume prune -f  # 清除所有未使用的卷

# 输出清理后的磁盘使用情况
echo -e "${GREEN}========================= 磁盘清理后 =========================${NC}"
df -h  # 输出磁盘使用情况

# 计算并报告清理掉的空间
echo -e "${GREEN}========================= 本次清理报告 =========================${NC}"
space_before=$(df --output=used / | tail -n 1)  # 获取清理前的磁盘使用量
sleep 1
space_after=$(df --output=used / | tail -n 1)  # 获取清理后的磁盘使用量
space_freed=$((space_before - space_after))  # 计算释放的空间
echo -e "${GREEN}本次清理释放了 ${space_freed} KB 的空间${NC}"

# 完成清理
echo -e "${RED}磁盘清理完成！${NC}"

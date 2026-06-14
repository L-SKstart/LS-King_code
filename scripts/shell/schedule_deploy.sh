#!/bin/bash
LOG=/opt/aj-eport/schedule_deploy.log
echo "=== 定时部署开始: $(date) ===" > $LOG

# Step ① 15:34 目录 (等35分钟)
echo "[1/7] 等待15:34..." >> $LOG
sleep 2100
find /opt/aj-eport -type d -exec touch -t $(date +%Y%m%d%H%M) {} \;
echo "[1/7] 目录 done: $(date)" >> $LOG

# Step ② 15:39 MySQL日志 (等5分钟)
sleep 300
touch -t $(date +%Y%m%d%H%M) /usr/bin/mysql/logs/mysqld_error.log 2>/dev/null
echo "[2/7] MySQL日志 done: $(date)" >> $LOG

# Step ③ 15:44 SQL (等5分钟)
sleep 300
find /opt/aj-eport -name '*.sql' -exec touch -t $(date +%Y%m%d%H%M) {} \;
echo "[3/7] SQL done: $(date)" >> $LOG

# Step ④ 15:49 bootstrap.yml (等5分钟)
sleep 300
touch -t $(date +%Y%m%d%H%M) /opt/aj-eport/aj-report-1.7.1.RELEASE/conf/bootstrap.yml
echo "[4/7] bootstrap.yml done: $(date)" >> $LOG

# Step ⑤ 15:54 docker-compose.yml (等5分钟)
sleep 300
touch -t $(date +%Y%m%d%H%M) /opt/aj-eport/onlyoffice/docker-compose.yml
echo "[5/7] docker-compose.yml done: $(date)" >> $LOG

# Step ⑥ 15:59 脚本 + 启动Java (等5分钟)
sleep 300
touch -t $(date +%Y%m%d%H%M) /opt/aj-eport/aj-report-1.7.1.RELEASE/bin/start.sh /opt/aj-eport/aj-report-1.7.1.RELEASE/bin/stop.sh /opt/aj-eport/aj-report-1.7.1.RELEASE/bin/restart.sh
echo "[6/7] 脚本 done: $(date) -> 启动Java" >> $LOG
cd /opt/aj-eport/aj-report-1.7.1.RELEASE/bin; bash ./start.sh >> $LOG 2>&1
echo "[6/7] Java启动完成: $(date)" >> $LOG

# Step ⑦ 16:04 .md (等5分钟)
sleep 300
find /opt/aj-eport -name '*.md' -exec touch -t $(date +%Y%m%d%H%M) {} \;
echo "[7/7] .md done: $(date)" >> $LOG

echo "=== 定时部署完成: $(date) ===" >> $LOG

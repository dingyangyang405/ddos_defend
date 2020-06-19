#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
port=80 
timerecovery=60 
mailurl='http://mail.operation.codeages.net/' #注意修改报警邮件发送服务器的网址
dir=$(cd `dirname $0`; pwd)
touch ${dir}/back_bad_ip.log
time=`date +"%Y-%m-%d %H:%M:%S"`
ar=`wc -l ${dir}/back_bad_ip.log |awk '{print $1}'` 
allrecord=`ss -ntu state all| sort`
attackip=`echo "$allrecord" | grep ":$port" |awk '{print $6 }'|sort | grep -v ":$port$"| egrep -v '192.168|127.0|\*' | awk -F":" '{print $1}' | sed -n '/[0-9]/p' |uniq -c | awk '{if ($2!=null && $1>100) {print $1,$2}}'`
if [[ -n "$attackip" ]]; then
	attackrecord=`echo "$allrecord" |grep "$(echo "$attackip" | awk '{print $2}')"`
	echo "$attackip" |awk -vtime="$time" '{print time"    |    " $1"    |    "$2}' >> ${dir}/back_bad_ip.log
	for i in `echo "$attackip" | awk '{print $2}'`
	do
		isexist=`iptables -L -nv | grep "$i"`
		if [[ -z "$isexist" ]]; then
			iptables -I INPUT -s $i -j DROP
			echo "iptables -D INPUT -s $i -j DROP" | at now + "$timerecovery" minutes &> /dev/null
		fi
	done
fi
ar2=`wc -l ${dir}/back_bad_ip.log |awk '{print $1}'`
let num=$ar2-$ar
if [[ "$num" -gt 0 ]]; then
	hostname=`cat /etc/hostname`
	ip=`curl -s ident.me`
	domain=`grep 'server_name' '/etc/nginx/sites-enabled/edusoho' | sed 's/server_name//' | sed 's/;//'`
	record=`tail -n $num ${dir}/back_bad_ip.log`
	echo -e "\n$time host($hostname) ip($ip) domain($domain) may be attacked by $num IP address currently! \n$record\n\nThe following is a real-time record:\n$attackrecord\n" > ${dir}/ddos_defense_record.log
	echo -e "\n$time host($hostname) ip($ip) domain($domain) may be attacked by $num IP address currently! \n$record\n\nThe following is a real-time record:\n$allrecord\n" >> ${dir}/ddos_defense_record_back.log	
	sed -i 's#$#&<br />#g' ${dir}/ddos_defense_record.log
	curl -d @${dir}/ddos_defense_record.log "${mailurl}?to=dingyangyang@howzhi.com,zhouxiaohui@howzhi.com,wangjianping@howzhi.com&subject=DDoS-Warning&who=edusoho_operation"
elif [[ "$num" -eq 0 && -s "${dir}/ddos_defense_record.log" ]]; then
	> ${dir}/ddos_defense_record.log
	hostname=`cat /etc/hostname`
    ip=`curl -s ident.me`
	domain=`grep 'server_name' '/etc/nginx/sites-enabled/edusoho' | sed 's/server_name//' | sed 's/;//'`
	content="$time DDoS Attack is stoped, host($hostname) ip($ip) domain($domain) status is OK!"
	curl -d "$content" "${mailurl}?to=dingyangyang@howzhi.com,zhouxiaohui@howzhi.com,wangjianping@howzhi.com&subject=DDoS-OK&who=edusoho_operation"
fi
exit 0

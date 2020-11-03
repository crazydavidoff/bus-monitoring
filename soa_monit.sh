#!/bin/bash

PATH=/usr/bin/monit_osb5
XML_POST_DATA=`/bin/cat $PATH/prod-main-request.xml`
URL=
login=
exportfile=/tmp/soa_monit5
count=0
time_req_summ=0
log=/tmp/log_soa_monit5

/bin/cp $PATH/request_orig.xml $PATH/request.xml
time_main1=`/bin/date '+%s%N'`
/usr/bin/curl -k -s -u$login --data-binary "$XML_POST_DATA" -H"Content-Type: text/xml" $URL > $PATH/response1.xml
time_main2=`/bin/date '+%s%N'`
time_main_request=$(( ($time_main2 - $time_main1) / 1000000 ))

if [ ! -s $PATH/response1.xml ]
then
        echo "0" > $exportfile
        echo >> $log
        /bin/date >> $log
        echo "Size of response1.xml = 0" >> $log
        echo "Submit time request: $time_main_request " >> $log
        /bin/cat $PATH/response1.xml >> $log
exit 0
fi

applicationId=`/usr/bin/xmlstarlet sel -t -v "//*[name()='applicationId']" $PATH/response1.xml`
status=`/usr/bin/xmlstarlet sel -t -v "//*[name()='status']" $PATH/response1.xml`

if [ $status != "ACCEPTED" ]
then
        echo "0" > $exportfile
        echo >> $log
        /bin/date >> $log
        echo "Status is not ACCEPTED" >> $log
        echo "Submit time request: $time_main_request " >> $log
        /bin/cat $PATH/response1.xml >> $log
exit 0
fi

echo `/usr/bin/xmlstarlet ed -u "//*[name()='ws:applicationId']" -v $applicationId $PATH/request.xml` > $PATH/request.xml

XML_POST_DATA=`/bin/cat $PATH/request.xml

while [ $status != "COMPLETED" ]
        do
        count=$(( $count + 1 ))
        if [ $count -eq 25 ]
        then
                echo "0" > $exportfile
                echo >> $log
                /bin/date >> $log
                echo "Status is not COMPLETED after 10 iterations" >> $log
                echo "Submit time request: $time_main_request " >> $log
                /bin/cat $PATH/response1.xml >> $log
                /bin/cat $PATH/response2.xml >> $log
                break
        fi
        /bin/sleep 1
        time_req1=`/bin/date '+%s%N'`
        /usr/bin/curl -k -s -u$login --data-binary "$XML_POST_DATA" -H"Content-Type: text/xml" $URL > $PATH/response2.xml
        time_req2=`/bin/date '+%s%N'`
        time_req=$(( $time_req2 - $time_req1 ))

        time_req_summ=$(( $time_req_summ + $time_req ))

        status=`/usr/bin/xmlstarlet sel -t -v "//*[name()='status']" $PATH/response2.xml`
        
        if [ $status == "REJECTED" ]
        then
                echo "0" > $exportfile
                echo >> $log
                /bin/date >> $log
                echo "Status is REJECTED" >> $log
                break
        fi
done

rcvDate=`/usr/bin/xmlstarlet sel -t -v "//*[name()='rcvDate']" $PATH/response2.xml`
prdcRsltDate=`/usr/bin/xmlstarlet sel -t -v "//*[name()='prdcRsltDate']" $PATH/response2.xml`
rcvDate_unix=`/bin/date --date=$rcvDate '+%s'`
prdcRsltDate_unix=`/bin/date --date=$prdcRsltDate '+%s'`

totaltime=$(( ($prdcRsltDate_unix - $rcvDate_unix) * 1000 ))
time_req_avg=$(( $time_req_summ / $count / 1000000 ))

if [[ "$status" == "COMPLETED" ]]; then
        echo "1" > $exportfile
else
        echo "0" > $exportfile
fi

echo $totaltime >> $exportfile
echo $time_main_request >> $exportfile
echo $time_req_avg >> $exportfile

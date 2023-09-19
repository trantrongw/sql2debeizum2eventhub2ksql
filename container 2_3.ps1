# create eventhub namespace
az eventhubs namespace create -g $RESOURCE_GROUP -n $EVENTHUB_NAME --enable-kafka=true -l $LOCATION

# set variables
$EH_NAME=az eventhubs namespace list -g $RESOURCE_GROUP --query '[].name' -o tsv
$EH_CONNECTION_STRING=az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --name RootManageSharedAccessKey --namespace-name $EVENTHUB_NAME -o tsv --query 'primaryConnectionString'

# pull debezium/connect and create container
az container create -g $RESOURCE_GROUP -n $CONTAINER_NAME `
        --image debezium/connect:$DEBEZIUM_VERSION `
        --ports 8083 --ip-address Public `
        --os-type Linux --cpu 2 --memory 4 `
        --environment-variables `
                BOOTSTRAP_SERVERS=$EH_NAME.servicebus.windows.net:9093 `
                GROUP_ID=1 `
                CONFIG_STORAGE_TOPIC=debezium_configs `
                OFFSET_STORAGE_TOPIC=debezium_offsets `
                STATUS_STORAGE_TOPIC=debezium_status `
                CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE=false `
                CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE=true `
                CONNECT_REQUEST_TIMEOUT_MS=60000 `
                CONNECT_SECURITY_PROTOCOL=SASL_SSL `
                CONNECT_SASL_MECHANISM=PLAIN `
                CONNECT_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\""$ConnectionString\"" password=\""$EH_CONNECTION_STRING\"";" `
                CONNECT_PRODUCER_SECURITY_PROTOCOL=SASL_SSL `
                CONNECT_PRODUCER_SASL_MECHANISM=PLAIN `
                CONNECT_PRODUCER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\""$ConnectionString\"" password=\""$EH_CONNECTION_STRING\"";" `
                CONNECT_CONSUMER_SECURITY_PROTOCOL=SASL_SSL `
                CONNECT_CONSUMER_SASL_MECHANISM=PLAIN `
                CONNECT_CONSUMER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\""$ConnectionString\"" password=\""$EH_CONNECTION_STRING\"";"

#get container IP, put in variable
$DEBEZIUM_IP=az container show -g $RESOURCE_GROUP -n $CONTAINER_NAME -o tsv --query "ipAddress.ip"
$ConnectionString='$ConnectionString'

#create schemahistory eventhub
az eventhubs eventhub create --name "schemahistory.customer"  -g $RESOURCE_GROUP  --namespace-name $EVENTHUB_NAME

# generate config REST body
$RESTBODY='
{
    "name": "deb",
    "config": {
        "snapshot.mode": "schema_only",
        "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
		"topic": "schemahistory.customer",
        "database.hostname": "$SQLSERVERNAME.database.windows.net",
        "database.port": "1433",
        "database.user": "$SQLADMINUSERNAME",
        "database.password": "$SQLADMINPASSWORD",
        "database.names": "$SQLDATABASENAME",
        "database.server.name": "SQLAzure",
		"database.encrypt": "false",
        "table.include.list": "dbo.debezum-cdcsql",
	    "decimal.handling.mode": "string",
	    "transforms": "Reroute",
	    "transforms.Reroute.type": "io.debezium.transforms.ByLogicalTableRouter",
	    "transforms.Reroute.topic.regex": "(.*)",
	    "transforms.Reroute.topic.replacement": "transmute",
	    "tombstones.on.delete": false,
		"topic.prefix": "customer",
        "schema.history.internal.kafka.bootstrap.servers": "$EH_NAME.servicebus.windows.net:9093", 
        "schema.history.internal.kafka.topic": "schemahistory.customer",
        "schema.history.internal.consumer.security.protocol": "SASL_SSL",
        "schema.history.internal.consumer.sasl.mechanism": "PLAIN",
        "schema.history.internal.consumer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"$EH_CONNECTION_STRING\";",
        "schema.history.internal.producer.security.protocol": "SASL_SSL",
        "schema.history.internal.producer.sasl.mechanism": "PLAIN",
        "schema.history.internal.producer.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"$EH_CONNECTION_STRING\";"

    }
}'
# expand strings, note $ConnectionString
$RESTBODY =  $ExecutionContext.InvokeCommand.ExpandString($RESTBODY)


Start-Sleep -seconds 10

Invoke-RestMethod -Method Post -Uri "http://$DEBEZIUM_IP`:8083/connectors/" -Headers @{'Accept' = 'application/json'; 'Content-Type' = 'application/json'} -Body $RESTBODY

Start-Sleep -seconds 2

#Check status of connector
Invoke-RestMethod -Method Get -Uri "http://$DEBEZIUM_IP`:8083/connectors/deb/status"

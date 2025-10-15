# Glue Crawler


```bash
aws glue start-crawler --name curated-device-telemetry-crawler


```




```sql
SELECT device_id, AVG(temperature) AS avg_temp
FROM device_telemetry
WHERE year='2025' AND month='10' AND day='15'
GROUP BY device_id
ORDER BY avg_temp DESC;
```
# query_express_logistics_information
通过抓取代理IP并调用快递100的查询接口查询快递物流信息。有价值的参考部分为抓取和筛选有效代理IP
#Usage
``` ruby
    express = ExpressQuery.new
    #bar_code 运单号 company 快递公司名字（汉字）
    express.query(bar_code,company)
```
#依赖
http
nokogiri
multi_json
redis

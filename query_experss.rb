require 'http'
require 'nokogiri'
require 'multi_json'
require 'redis'
# http://www.kuaidi100.com/query?type=yuantong&postid=560310550055&id=1&valicode=&temp=0.9320737529178553
class ExpressQuery
  include HTTP
  def initialize
    $redis = Redis.new
  end

  COMPANY_NAME = {huitongkuaidi: '百世汇通',shentong: '申通', shunfeng: '顺丰',
                  yuantong: '圆通速递', yunda: '韵达快运'}

  def query(bar_code,company_name,option={cache: true})
    return JSON.parse($redis.get("bar_code_#{bar_code}")) if option[:cache] && $redis.exists("bar_code_#{bar_code}")
    company = self.class::COMPANY_NAME.key(company_name).to_s
    retry_times = 0
    begin
      proxy = get_proxy
      p "#{proxy.first}:#{proxy.last}"
      response = HTTP.via(proxy.first, proxy.last.to_i)
                     .timeout(:global, {connect: 6, read: 6})
                     .headers('Referer': 'http://www.kuaidi100.com/',
                              'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36')
                     .get("http://www.kuaidi100.com/query?type=#{company}&postid=#{bar_code}&id=1&valicode=&temp=#{rand}")

      data = JSON.parse(response)['data'].reverse!
      #缓存3小时
      $redis.setex("bar_code_#{bar_code}",60*60*3,JSON.dump(data))
      data
    rescue
      $redis.srem(:proxies,"#{proxy.first}:#{proxy.last}") unless proxy.nil?
      (retry_times += 1) < 5 ? retry : nil
    end
  end

  private

  def get_proxy_list
    proxies = []
    (1..3).each do |page|
      proxies += get_url('nt',page) #国内透明
      proxies += get_url('nn',page) #国内高匿
    end
    proxies
  end

  def get_url(type,page)
    proxies = []
    doc = Nokogiri::HTML(HTTP.get("http://www.xicidaili.com/#{type}/#{page.to_s}").to_s)
    doc.css("//div//table//tr").each do |item|
      next if item.elements[6].children[1].nil?
      next if item.elements[6].children[1].attributes['title'].value.gsub('秒','').to_f > 0.5
      next if item.elements[8].children[0].text.include?('小时') && item.elements[8].children[0].text.gsub('小时','').to_i < 20
      proxies << "#{item.elements[1].children.text}:#{item.elements[2].children.text}" if check_proxy(item.elements[1].children.text,item.elements[2].children.text.to_i)
    end
    proxies
  end

  def check_proxy(ip,port)
    begin
      HTTP.via(ip,port).timeout({connect: 6,read: 6}).get('http://www.baidu.com').code == 200
    rescue
      false
    end
  end

  def get_proxy
    unless $redis.exists(:proxies) && $redis.scard(:proxies) != 0
      $redis.sadd(:proxies,get_proxy_list)
      $redis.expire(:proxies, 60*60*2)
    end
    $redis.srandmember(:proxies).split(':')
  end
end


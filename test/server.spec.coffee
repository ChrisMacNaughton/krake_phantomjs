express = require 'express'
KSON = require 'kson'
request = require 'request'
testClient = require './fixtures/test_client'

jasmine.getEnv().defaultTimeoutInterval = 20000

describe "testing to make sure phantomjs server is running", ()->
  it "should respond with I am Krake", (done)->
    request "http://localhost:9701/", (error, response, body)->
      expect(body).toEqual "I am Krake"
      done()

describe "testing badly formed JSON", ()->
  it "should respond with error message", (done)->
    testClient '{what the fuck', (response_obj)-> 
      expect(response_obj.status).toEqual "error"
      expect(response_obj.message).toEqual "cannot render Krake query object, SyntaxError: KSON.parse"
      done()
    
describe "testing bad page on lelong.com.my", ()->
  it "should not crash", (done)->
    post_data = KSON.stringify(
      "exclude_jquery" : true
      "origin_url": "http://www.lelong.com.my/Auc/Feedback/UserRating.asp?UserID=CoconutIsland@1",
      "columns": [{
        "col_name": "email address"
        "xpath": '//*[@id="SellerInfoContainer"]/table/tbody/tr[2]/td[3]/a'
        "required_attribute" : 'href'
      }]
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "error"
      expect(typeof response_obj.message).toBe "object"
      expect(typeof response_obj.message.result_rows).toBe "object"
      done() 

describe "phantom server cookie testing", ()->

  app = false
  beforeEach ()=>
    # Running test server
    app = module.exports = express.createServer()
    app.configure ()->
      app.use(express.cookieParser())
      app.use(express.bodyParser())
      app.use(app.router)
    app.get '/', (req, res)->
      if req.cookies['x-li-idc'] == 'C1'
        res.send 'cookie header received'
      else
        res.send 'cookie header not received'
    app.listen 9999
  
  afterEach ()=>
    app.close()
  
  it "should respond with success as well as cookie received", (done)->
    post_data = KSON.stringify(
      "origin_url": "http://localhost:9999/"
      "columns": [{
        "col_name": "body"
        "dom_query" : "body"
      },{
        "col_name": "name"
        "xpath": "/html[1]/body[1]/div/div[1]/div[2]/div[1]/div[5]/div[3]/ol[1]/li[1]/div[1]/h3[1]/a[1]"
      }]
      "cookies": [{
        "domain": "localhost"
        "hostOnly": true
        "httpOnly": false
        "name": "X-LI-IDC"
        "path": "/cookie"
        "secure": false
        "session": true
        "storeId": "0"
        "value": "C1"
      }]
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      expect(typeof response_obj.message).toBe "object"
      expect(response_obj.message.result_rows[0].body).toEqual "cookie header received"
      done()

describe "testing Krake definition with jQuery excluded", ()->
  it "should respond with success and an object ", (done)->
    
    post_data = KSON.stringify(
      exclude_jquery : true,
      origin_url : 'http://sg.yahoo.com/?p=us'
      columns: [{
        col_name: 'product_name'
        dom_query: '.lrg.bold'
      },{
        col_name: 'product_image'
        dom_query: '.image img'
        required_attribute : 'src'        
      },{        
        col_name : 'price'
        dom_query : 'span.bld.lrg.red' 
      }, {
        col_name: 'detailed_page'
        dom_query: '.newaps a'
        required_attribute : 'href'
        options :
          columns : [{
            col_name : 'product_description'
            dom_query : '#productDescription'
          }]
      }]
      data :
        source : 'amazon'
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      expect(typeof response_obj.message).toBe "object"
      done() 

describe "test extraction of Geolocation from Google", ()->
  it "should respond with success and an object ", (done)->

    post_data = KSON.stringify(
      "exclude_jquery" : true,
      "origin_url": "http://maps.googleapis.com/maps/api/geocode/xml?sensor=false&address=29%20Club%20Street+Singapore",
      "columns": [{
          "col_name": "Latitude",
          "xpath": "//GeocodeResponse/result/geometry/location/lat",
          "required_attribute" : 'textContent'
        },{
          "col_name": "Longitude",
          "xpath": "//GeocodeResponse/result/geometry/location/lng",
          "required_attribute" : 'textContent'              
        },{
          "col_name": "Postal Code",
          "xpath": "//GeocodeResponse/result/address_component[5]/long_name",
          "required_attribute" : 'textContent'              
      }]
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      expect(typeof response_obj.message).toBe "object"
      expect(typeof response_obj.message.result_rows).toBe "object"
      expect(typeof response_obj.message.result_rows[0]).toBe "object"
      expect(typeof response_obj.message.result_rows[0].Latitude).toEqual "string"
      expect(typeof response_obj.message.result_rows[0].Longitude).toEqual "string"
      expect(response_obj.message.result_rows[0]['Postal Code']).toEqual "Singapore"
      done() 

describe "test extraction of Product Listing Info from MDScollections using Xpath", ()->
  it "should respond with success and an object ", (done)->
    post_data = KSON.stringify(
      origin_url : "http://www.mdscollections.com/cat-new-in-clothing.cfm"
      columns : [{
          col_name : 'product_name'
          xpath : '//a[@class="listing_product_name"]'
          is_index : true
        },{
          col_name : 'product_price'
          xpath : '//span[@class="listing_price"]'
      }]
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      expect(typeof response_obj.message).toBe "object"
      expect(typeof response_obj.message.result_rows).toBe "object"
      expect(typeof response_obj.message.result_rows[0]).toBe "object"
      expect(typeof response_obj.message.result_rows[0].product_name).toBe "string"        
      expect(typeof response_obj.message.result_rows[0].product_price).toBe "string"
      expect(response_obj.message.result_rows.length).toBeGreaterThan 5
      done()

describe "testing Krake definition with no origin url", ()->
  it "should respond with an error ", (done)->
    post_data = KSON.stringify(
      origin_url : 'http://www.amazon.com/s/ref=nb_sb_noss?url=search-alias%3Daps&field-keywords=iphone'      
      data :
        source : 'amazon'
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "error"
      expect(response_obj.message).toEqual "columns not defined"
      done() 
    
describe "testing Krake definition with no origin url", ()->
  it "should respond with an error ", (done)->
    post_data = KSON.stringify(
      columns: [{
          col_name: 'product_name'
          dom_query: '.lrg.bold'
        },{
          col_name: 'product_image'
          dom_query: '.image img'
          required_attribute : 'src'        
        },{        
          col_name : 'price'
          dom_query : 'span.bld.lrg.red' 
        }, {
          col_name: 'detailed_page'
          dom_query: '.newaps a'
          required_attribute : 'href'
          options :
            columns : [{
              col_name : 'product_description'
              dom_query : '#productDescription'
            }]
      }]
      data :
        source : 'amazon'
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "error"
      expect(response_obj.message).toEqual "origin_url not defined"
      done() 
    
describe "testing against non-existant url", ()->
  it "should respond with error and error an empty array for result_rows attribute in message object ", (done)->
    post_data = KSON.stringify(
      origin_url : 'http://somewhere_over_the_rainbow'
      columns: [{
          col_name: 'product_name'
          dom_query: '.lrg.bold'
        },{
          col_name: 'product_image'
          dom_query: '.image img'
          required_attribute : 'src'        
        },{        
          col_name : 'price'
          dom_query : 'span.bld.lrg.red' 
        }, {
          col_name: 'detailed_page'
          dom_query: '.newaps a'
          required_attribute : 'href'
          options :
            columns : [{
              col_name : 'product_description'
              dom_query : '#productDescription'
            }]
      }]
      data :
        source : 'amazon'
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "error"
      expect(response_obj.message.result_rows).toEqual []
      done() 
    
describe "test JSON parse UTF8 in phantomjs", ()->
  it "should respond with success", (done)->
    try
      payload = '{"dom_query":"li:contains(\'商店地址\')"}'
      payload_obj = JSON.parse payload
    catch e

    expect(typeof payload_obj).toBe "object"          
    expect(payload_obj["dom_query"]).toEqual "li:contains('商店地址')"
    done()
    
describe "testing well formed Krake definition", ()->
  it "should respond with success and an object ", (done)->
    post_data = KSON.stringify(
      "exclude_jquery" : true
      "origin_url": "http://maps.googleapis.com/maps/api/geocode/xml?sensor=false&address=29%20Club%20Street+Singapore"
      "columns": [{
        "col_name": "Latitude"
        "xpath": "//GeocodeResponse/result/geometry/location/lat"
        required_attribute : 'textContent'
      },{
        "col_name": "Longitude"
        "xpath": "//GeocodeResponse/result/geometry/location/lng"
        required_attribute : 'textContent'              
      },{
        "col_name": "Postal Code"
        "xpath": "//GeocodeResponse/result/address_component[5]/long_name"
        required_attribute : 'textContent'              
      }]
    )
    
    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      expect(typeof response_obj.message).toBe "object"
      done() 
    
describe "Test to ensure extreme long JSON query gets handled properly", ()->
  it "should respond with success and an object ", (done)->
    post_data =
        "origin_url": "http://tw.mall.yahoo.com/merchant_homepage?catid=0&searchby=sname&sort_by=product_count&order_by=0"
        "columns": [{
            "col_name": "shop rating"
            "xpath": "/html[1]/body[1]/div/div[1]/div[2]/div[1]/div[1]/div[1]/div[3]/div[2]/table[1]/tbody[1]/tr/td[1]/p[1]/span[1]/a[1]"
        },{
            "xpath": "/html[1]/body[1]/div/div[1]/div[2]/div[1]/div[1]/div[1]/div[3]/div[2]/table[1]/tbody[1]/tr/td[1]/p[1]/span[1]/a[1]"
            "col_name": "shop rating page"
            "required_attribute": "href"
            "options":
                "columns": [{
                    "col_name": "shop name"
                    "dom_query": ".title h1"
                },{
                    "col_name": "past week viewer traffic"
                    "xpath": "/html[1]/body[1]/div/div[3]/div[2]/div[1]/div[1]/div[1]/div[1]/div[2]/div[1]/div[1]/div[1]/div[1]/div[1]/div[2]/div[1]/div[2]"
                    "regex_pattern": /[0-9]+/gi
                    "regex_group": 0
                },{
                    "col_name": "number of rating"
                    "xpath": "/html[1]/body[1]/div/div[3]/div[2]/div[1]/div[1]/div[1]/div[2]/div[2]/div[1]/div[1]/div[1]/div[2]/div[1]/span[1]"
                    "regex_pattern": /[0-9]+/gi
                    "regex_group": 2
                },{
                    "col_name": "shop contact page"
                    "dom_query": "a:contains('商店介紹')"
                    "required_attribute": "href"
                    "options":
                      "columns": [{
                        "col_name": "phone"
                        "dom_query": "li:contains('服務電話')"
                        "regex_pattern": /[0-9]+/
                      },{
                        "col_name": "shop fax"
                        "dom_query": "li:contains('傳真號碼')"
                        "regex_pattern": /[0-9]+/
                      },{
                        "col_name": "address"
                        "dom_query": "li:contains('商店地址')"
                        "regex_pattern": /[^：]+/gi
                        "regex_group": 1
                      },{
                        "col_name": "person in charge"
                        "dom_query": "li:contains('商業負責人')"
                        "regex_pattern": /[^：]+/gi
                        "regex_group": 1
                      },{
                        "col_name": "shop name"
                        "dom_query": "li:contains('商店名稱')"
                        "options":
                            "origin_url": "@@shop rating page@@"
                            "columns": [{
                              "col_name": "category"
                              "dom_query": "#ypsuf h4 a"
                              "options":
                                "origin_url": "@@category page@@&view=both"
                                "columns": [{
                                  "col_name": "product name"
                                  "dom_query": ".yui-g:contains('全部商品') .title a, .bd .desc a"
                                },{
                                  "col_name": "product price"
                                  "dom_query": "span:contains(\"元\"), .price strong"
                                  "regex_pattern": /[0-9]+/gi
                                },{
                                  "col_name": "time sold"
                                  "dom_query": "li:contains(\"購買人次\")"
                                  "regex_pattern": /[0-9]+/gi
                                }]
                            },{
                              "col_name": "category page"
                              "dom_query": "#ypsuf h4 a"
                              "required_attribute": "href"
                            }]
                      }]
                }]
        }]
        "next_page":
            "dom_query": ".pages strong+a"

    post_data = encodeURIComponent(KSON.stringify(post_data))
    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      done() 
    
describe "Test to ensure UTF8 declarations gets handled properly", ()->
  it "should respond with success and an object ", (done)->
    post_data = 
      "origin_url": "http://tw.mall.yahoo.com/search?m=list&sid=taaze&ccatid=2376&s=-sc_salerank&view=both&path=2376",
      "columns": [{
        "col_name": "product name"
        "dom_query": ".yui-g:contains('全部商品') .title a, .bd .desc a"
      },{
        "col_name": "product price"
        "dom_query": "span:contains(\"元\"), .price strong"
        "regex_pattern": /[0-9]+/gi
      },{
        "col_name": "time sold"
        "dom_query": "li:contains(\"購買人次\")"
        "regex_pattern": /[0-9]+/gi
      }]

    post_data = encodeURIComponent(KSON.stringify(post_data));
    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      done() 
    
describe "Test to ensure UTF8 encoding gets handled properly", ()->
  it "should respond with success and an object ", (done)->
    post_data = encodeURIComponent(KSON.stringify('全部商品'))
    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "error"
      done() 
    
describe "to ensure special Yalwa corner case gets handled properly", ()->
  it "should respond with success and an object ", (done)->
    post_data = KSON.stringify(
      origin_url : "http://www.yalwa.sg/",
      columns: [{
          col_name: "cat 1",
          dom_query: "#tabs a"
      }]
    )

    testClient post_data, (response_obj)-> 
      expect(response_obj.status).toEqual "success"
      expect(typeof response_obj.message).toBe "object"
      done() 
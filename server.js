// This files is to be ran using PhantomJS

// Creation of web server
var server = require('webserver').create();


// @Description : Given a page object sets the header for this object
// @param : page:object
var setDefaultHeader = function(page) {
  console.log("[PHANTOM_SERVER] Setting user agent headers");
  page.settings['userAgent'] = 
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1';
  return page;
  
};



// @Description : Opens the page, extracts the data and returns the response
// @param : page:Object
// @param : krake_query_obj:Object
// @param : callback:function
//    status:String
//    results:Object
//        result_rows:Array
//          result_row:Object
//            attribute1:String value1 - based on required_attribute
//            attribute2:String value2 - based on required_attribute
//            ...
//        next_page:String — value to next page href
var openPage = function(page, krake_query_obj, callback) {
  console.log("[PHANTOM_SERVER] Opening page");

  // @extracts the DOM elements from the page  
  var extractDomElements = function() {
    page.render('facebook-phantom.pdf');
  	console.log('[PHANTOM_SERVER] extracting DOM elements');    

    // @Description : extracts value from page
    // @return: 
    //    results:Object
    //        result_rows:Array
    //          result_row:Object
    //            attribute1:String value1 - based on required_attribute
    //            attribute2:String value2 - based on required_attribute
    //            ...
    //        next_page:String — value to next page href
    //        logs:Array
    //          log_mesage1:String, ...
    var results = page.evaluate(function(krake_query_obj) {
      
      // Gets the value of a DOM attribute
       var extractAttributeFromDom = function(dom_obj, required_attribute) {

         var return_val = '';

         switch(required_attribute) {
           case 'href'       :
           case 'src'        :
             return_val = dom_obj[required_attribute];
             break;

           case 'innerHTML'  : 
             return_val = dom_obj.innerHTML;
             break;

           case 'innerText'  :
           case 'textContent':
           case 'address'    :
           case 'email'      :
           case 'phone'      :
             return_val = dom_obj.textContent || dom_obj.innerText;
             break;

           default : 
             return_val = required_attribute && dom_obj.getAttribute(required_attribute)
             !return_val && (return_val = dom_obj.textContent)
         }

         return return_val.trim();

       }      
      
      var results = {};
      results.logs = [];
      results.result_rows = [];

      // Goes through each columns
      for(var x = 0; x < krake_query_obj.columns.length ; x++) {
        
        var curr_column = krake_query_obj.columns[x];
        
        // when jQuery selector is to be used        
        if( (typeof jQuery == "function") && curr_column.dom_query) {
          results.logs.push("[PHANTOM_SERVER] extract using jQuery" + 
            "\r\n\t\tcol_name:" + curr_column.col_name +
            "\r\n\t\tdom_query:" + curr_column.dom_query);
          var jquery_results = jQuery(curr_column.dom_query);
          for (var y = 0; y < jquery_results.length ; y++ ) {
            var curr_result_row = results.result_rows[y] || {};
            curr_result_row[curr_column['col_name']] = extractAttributeFromDom(jquery_results[y], curr_column['required_attribute']);
            results.result_rows[y] = curr_result_row;
          }
        
        // when jQuery has been explicitly excluded
        } else if( (typeof jQuery != "function") && curr_column.dom_query) {
          results.logs.push("[PHANTOM_SERVER] extract using CSS Selector" + 
            "\r\n\t\tcol_name:" + curr_column.col_name +
            "\r\n\t\tdom_query:" + curr_column.dom_query);
            
          var query_results = document.querySelectorAll(curr_column.dom_query);
          for (var y = 0; y < query_results.length ; y++ ) {
            var curr_result_row = results.result_rows[y] || {};
            curr_result_row[curr_column['col_name']] = extractAttributeFromDom(query_results[y], curr_column['required_attribute']);
            results.result_rows[y] = curr_result_row;
          }          

        // when xpath is to be sued
        } else if(curr_column.xpath) {

          results.logs.push("[PHANTOM_SERVER] extract using Xpath" + 
            "\r\n\t\tcol_name:" + curr_column.col_name +
            "\r\n\t\tdom_query:" + curr_column.xpath );

          var xPathResults = document.evaluate(curr_column.xpath, document);  
          var curr_item;
          var y = 0;
          
          while(curr_item = xPathResults.iterateNext()) {
            var curr_result_row = results.result_rows[y] || {}; 
            curr_result_row[ curr_column['col_name'] ] = extractAttributeFromDom(curr_item, curr_column['required_attribute']);
            results.result_rows[y] = curr_result_row;
            y++;
          }
          
        // when both xpath and dom_query are missing
        } else {
          results.logs.push("[PHANTOM_SERVER] dom selector is missing" + 
            "\r\n\t\col_name:" + curr_column['col_name']);
          
        }

        
      } // eo iterating through krake columns
      
      
      
      // gets the next page hyperlink if it exist and use Xpath
      if(krake_query_obj.next_page && krake_query_obj.next_page.xpath) { 
        results.logs.push("[PHANTOM_SERVER] extracting next page using Xpath" + 
            "\r\n\t\txpath : " + krake_query_obj.next_page.xpath);
        var xPathResults = document.evaluate(krake_query_obj.next_page.xpath, document);  
        var xpath_np;
        while(xpath_np = xPathResults.iterateNext()) {
           results.next_page = xpath_np.getAttribute('href');
        }        
        
      } else if(krake_query_obj.next_page && krake_query_obj.next_page.dom_query) {
        results.logs.push("[PHANTOM_SERVER] extracting next page using jQuery" + 
            "\r\n\t\tdom_query : " + krake_query_obj.next_page.dom_query);
        var jquery_np = jQuery(krake_query_obj.next_page.dom_query);
        jquery_np.length && (results.next_page = jQuery(jquery_np[0]).attribute('href'));
        
      } 

      return results;
        
    }, krake_query_obj); // eo evaluation
    console.log('[PHANTOM_SERVER] Extraction finished.');    
    console.log(JSON.stringify(results));
    callback('success', results);
    page.close();
  }

  
  // @Description : the process that holds up the loading of pages
  var waitUp = function() {

    if(krake_query_obj.wait && krake_query_obj.wait > 0 ) {
      console.log('[PHANTOM_SERVER] : waiting for ' + krake_query_obj.wait + ' milliseconds')
      setTimeout(function() {
        extractDomElements();
        
      }, krake_query_obj.wait);
    } else {
      extractDomElements();
      
    }
  }
  
  
  // @Description : the process that handles the finished loading of pages
  page.onLoadFinished = function(status) {
    // When opening page failed
  	if(status !== 'success') {
  	  console.log('[PHANTOM_SERVER] page failed to finish loading.');
      callback('error', 'page failed to finish loading');
      page.close();

    // when opening page was successful  		
  	} else {  		
  	  
  	  // when excludes the jquery library 
  	  if(krake_query_obj.exclude_jquery) {
  	    console.log('[PHANTOM_SERVER] jQuery excluded');
        waitUp();

  	  // when includes the jquery library           	      
  	  } else {
  	    console.log('[PHANTOM_SERVER] including jQuery');
  	    page.includeJs("https://api.krake.io/3p/js/jquery.js", function() {
  	      console.log('[PHANTOM_SERVER] jQuery included');
  	      waitUp();
	      });  	    
        
  	  }
  	}
  }
  
  // @Description : throws up the error
  page.onError = function (msg, trace) {
    console.log(msg);
    trace.forEach(function(item) {
        console.log('  ', item.file, ':', item.line);
    })
  };
  
  // @Description : opens the page
  page.open(krake_query_obj.origin_url, function(status) {
    
    // When opening page failed
  	if(status !== 'success') {
  	  console.log('[PHANTOM_SERVER] failed to open page.');
      callback('error', 'page opening failed');
      page.close();
  	} 
  	
  });
  
  
}



// @Description : catchs and displays the error
phantom.onError = function(msg, trace) {
  var msgStack = ['PHANTOM ERROR: ' + msg];
  if (trace && trace.length) {
      msgStack.push('TRACE:');
      trace.forEach(function(t) {
          msgStack.push(' -> ' + (t.file || t.sourceURL) + ': ' + t.line + (t.function ? ' (in function ' + t.function + ')' : ''));
      });
  }
  console.error(msgStack.join('\n'));
  phantom.exit(1);
};



// @Description : Given a page object sets the cookies for this object
// @param : page:object
// @param : cookies:array[]
var setCookies = function(page, krake_query_obj) {
  console.log("[PHANTOM_SERVER] Setting Cookies");
  if(krake_query_obj.cookies) {
    for( x = 0; x < krake_query_obj.cookies.length; x++) {
      console.log('Current cookie');
      console.log(JSON.stringify(krake_query_obj.cookies[x]));
      add_results = phantom.addCookie({
        name : krake_query_obj.cookies[x].name, 
        value : krake_query_obj.cookies[x].value, 
        domain : krake_query_obj.cookies[x].domain 
      });
      
      if(add_results) {
        console.log('Cookie was added');
        
      } else {
        console.log('Cookie was not added');
      }
      
    };    
  }
  return page;
  
};



// @Description : extracts the columns from the page
// @param : krake_query_obj:Object
// @param : callback:function
//    status:string - success || error
//    results:Object
var processPage = function(krake_query_obj, callback) {
  
  if(!krake_query_obj.origin_url ) {
    console.log('[PHANTOM_SERVER] origin_url not defined for \r\n\t\tURL:' + krake_query_obj.origin_url);
    callback && callback('error', 'origin_url not defined');
    return;
    
  } else if(!krake_query_obj.columns) {
    console.log('[PHANTOM_SERVER] columns not defined \r\n\t\tURL:' + krake_query_obj.origin_url);
    callback && callback('error', 'columns not defined');
    return;    
    
  } else {
    console.log('[PHANTOM_SERVER] Processing page \r\n\t\tURL:' + krake_query_obj.origin_url);
    var page = require('webpage').create();
    setCookies(page, krake_query_obj); 
    setDefaultHeader(page);
    openPage(page, krake_query_obj, function(status, results) {
      callback && callback(status, results);
      
    }) 
  }
  
};



// @Description : inclusion of jQuery
// @param : page


// The webserver
var service = server.listen(9701, function(req, res) {
  
  // Default route for testing purposes 
  if(req.url == '/') {
    res.statusCode = 200;
    res.write('I am Krake');
    res.close();
  
  // The actual route that Krake request will hit
  } else {
    
    var response = { 
      status : '', 
      message : ''
    }
    
    try {
      var krake_query_obj = JSON.parse(req.post);
      processPage(krake_query_obj, function(status, results) {
        response.status = status;
        response.message = results;
        res.write(JSON.stringify(response));
        res.close();

      });
      
    } catch (e) {
      response.status = 'error';
      response.message = 'cannot render Krake query object';
      res.write(JSON.stringify(response));
      res.close();      
      
    }
  }

});

console.log('Running phantom webserver at port : ', server.port);
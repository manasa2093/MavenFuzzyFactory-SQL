#ANALYZING TRAFFIC SOURCES
#Checking where the bulk of website_sessions are coming from ?

use mavenfuzzyfactory;
SET global time_zone = '-5:00';

SELECT utm_source, utm_campaign, http_referer, 
COUNT( DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at < '2012-04-12'
GROUP BY utm_source, utm_campaign, http_referer
ORDER BY sessions DESC;

#Results: Most of the sessions are coming from Gsearch and nonbrand

#Checking if gsearch, non brand are driving sales ? What is the conversion rate from sessions to orders? The Company needs to have atleast 4% to have the numbers work.

SELECT COUNT( DISTINCT ws.website_session_id) AS sessions, 
COUNT(DISTINCT o.order_id) AS orders, 
COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) AS session_order_conv_rate
FROM website_sessions ws
LEFT JOIN orders o
ON ws.website_session_id = o.website_session_id
WHERE ws.created_at < '2012-04-14' AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand';

#Results: The current session to order conversion rate is very low (below 4%), the company is overspending on the bids.Hence the company bid down non brannd traffic. 

#Checking the conversion rates from sessions to orders after bidding down, trended by weekly.

SELECT MIN(DATE(created_at)) as week_start_date , COUNT( DISTINCT website_session_id) AS sessions
FROM website_sessions ws
WHERE ws.created_at < '2012-05-10' 
AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at);

#Results : Seems like gsearch, nonbrand is very sensitive to bid changes, the bid changes had impact on the sessions to order convertion rates.

#Checking the conversion rates from session to order by device type

SELECT ws.device_type, COUNT(DISTINCT ws.website_session_id) AS sessions, COUNT( DISTINCT o.order_id) AS orders,
COUNT( DISTINCT o.order_id) /COUNT(DISTINCT ws.website_session_id) AS session_order_conv_rate
FROM website_sessions ws
LEFT JOIN orders o
ON ws.website_session_id = o.website_session_id
WHERE ws.created_at < '2012-05-11' 
AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand'
GROUP BY 1;

#Results : Between desktop and phone , desktop performs far better than phone. Hence increased bids for desktop.

#Analzying weekly trend for each device type after bidding up for desktop

SELECT MIN(DATE(created_at)), 
COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_session_id ELSE NULL END) AS desktop,
COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id  ELSE NULL END) AS mobile
FROM website_sessions 
WHERE created_at < '2012-06-09' AND  created_at > '2012-04-15'
AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at)
;

#Results : Increased bids for desktop made a positive impact on total session to order conversion rate! 

#ANALYZING WEBSITE PERFORMANCE

#Analyzing the most viewed pages, ranked by session volume. 

SELECT  pageview_url, COUNT( DISTINCT website_session_id) AS sessions
FROM website_pageviews
WHERE created_at < '2012-06-09' 
GROUP BY pageview_url
ORDER BY 2 DESC
;

#Results : Among everything, home, products and fuzzy have more sessions.

#Analyzing the top landing pages, ranked by session volume. 

CREATE TEMPORARY TABLE pageview_sessions
SELECT MIN(website_pageview_id) AS pageviews, website_session_id AS session_id
FROM website_pageviews
WHERE created_at < '2012-06-12' 
;

SELECT pageview_url , COUNT(DISTINCT pageviews) AS sessions_hitting_landing_page
FROM pageview_sessions ps
LEFT JOIN website_pageviews wp
ON wp.website_pageview_id = ps.pageviews
group by 1;

#Results: All the traffic is coming from homepage, so the company needs to optimizing the homepage to increase the revenue

#Calculating the bounce rates for traffic landing on the homepage? 

CREATE TEMPORARY TABLE minpageviews
SELECT website_session_id, MIN(website_pageview_id) AS pageview_id
FROM website_pageviews 
WHERE created_at < '2012-06-14' AND pageview_url = '/home'
GROUP BY 1;


CREATE TEMPORARY TABLE total_bounced_sessions;
SELECT mp.website_session_id,  count(wp.website_pageview_id) AS count 
FROM minpageviews mp
LEFT JOIN website_pageviews wp 
ON mp.website_session_id = wp.website_session_id 
GROUP BY 1;

SELECT count(website_session_id) AS total_sessions, 
COUNT( CASE WHEN count =1 THEN count ELSE NULL END) AS bounced_sessions,
COUNT( CASE WHEN count =1 THEN count ELSE NULL END) / count(website_session_id) as bounced_rate
FROM total_bounced_sessions;

#Results :The bounce rate is very high - 60%, meaning most of the customers are not proceeding further from the landing page. The company needs to improve the landing page to dirve business.

#The company has created a new custom landing page in 50/50 test against homepage. Calculate the bounce rates for these 2 groups. 

#Checking the first pageview and first created_at
SELECT website_pageview_id as first_pageview, created_at AS first_created_at 
FROM website_pageviews 
WHERE pageview_url = '/lander-1' AND created_at < '2012-07-28' ;

#first_pageview : 23504 & 2012-06-19 01:35:54


CREATE TEMPORARY TABLE minpage_view;
SELECT wp.website_session_id, MIN(wp.website_pageview_id) AS pageview_id
FROM website_pageviews wp
JOIN website_sessions ws
ON wp.website_session_id = ws.website_session_id
WHERE wp.website_pageview_id > '23504' and 
ws.created_at between '2012-06-19' AND '2012-07-28' 
AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand'
GROUP BY 1;

CREATE TEMPORARY TABLE minpage_view_url;
SELECT mpv.website_session_id,  mpv.pageview_id, wp.pageview_url 
FROM minpage_view mpv
LEFT JOIN website_pageviews wp 
ON mpv.pageview_id = wp.website_pageview_id;



CREATE TEMPORARY TABLE total_bouncedsessions;
SELECT mp.pageview_url, mp.pageview_id as total_sessions, COUNT(wp.website_pageview_id) as count
FROM minpage_view_url mp
LEFT JOIN website_pageviews wp 
ON mp.website_session_id = wp.website_session_id 
GROUP BY 2,1 
;

SELECT pageview_url, 
count(DISTINCT total_sessions) AS total_sessions, 
COUNT( CASE WHEN count =1 THEN count ELSE NULL END) AS bounced_sessions,
COUNT( CASE WHEN count =1 THEN count ELSE NULL END) / count(total_sessions) as bounced_rate
FROM total_bouncedsessions
GROUP BY 1;

#Results :The new lander page performs much better than the old one. hence, all the non brand traffic should be forwarded to new landing page. 

#Landing page trend analysis 
#Calculate the volume of paid search nonbrand traffic landing on /home and /lander-1, trended weekly 


CREATE TEMPORARY TABLE minpage_views;
SELECT wp.website_session_id, MIN(wp.website_pageview_id) AS pageview_id
FROM website_pageviews wp
JOIN website_sessions ws
ON wp.website_session_id = ws.website_session_id
WHERE 
ws.created_at between '2012-06-1' AND '2012-08-31' 
AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand'
GROUP BY 1;

CREATE TEMPORARY TABLE minpage_view_urls;
SELECT mpv.website_session_id,  mpv.pageview_id, wp.pageview_url , wp.created_at
FROM minpage_views mpv
LEFT JOIN website_pageviews wp 
ON mpv.pageview_id = wp.website_pageview_id;



CREATE TEMPORARY TABLE totalsessions;
SELECT MIN(DATE(mp.created_at)) as week_start, mp.pageview_url, mp.pageview_id as total_sessions, COUNT(wp.website_pageview_id) as count
FROM minpage_view_urls mp
LEFT JOIN website_pageviews wp 
ON mp.website_session_id = wp.website_session_id 
GROUP BY WEEK(mp.created_at), 3,2 

;

SELECT MIN(DATE(week_start)), 
COUNT( CASE WHEN pageview_url = '/home' THEN total_sessions ELSE NULL END) AS home_sessions,
COUNT( CASE WHEN pageview_url = '/lander-1' THEN total_sessions ELSE NULL END) AS lander_sessions,
COUNT( CASE WHEN count =1 THEN count ELSE NULL END) / (COUNT( CASE WHEN pageview_url = '/home' THEN total_sessions ELSE NULL END) + COUNT( CASE WHEN pageview_url = '/lander-1' THEN total_sessions ELSE NULL END)) AS RATE,
COUNT( CASE WHEN count =1 THEN count ELSE NULL END)  as bounced_ses
FROM totalsessions
GROUP BY  WEEK(week_start);

#Results: Bounce rates from home to lander-2 has reduced from 60 % to 50% which is a good improvement. More number of customers are moving ahead from landing page to another page.alter


#ANALYZING AND TESTING CONVERSION FUNNELS
#building a full conversion funnel from lander-1 to thankyou order page and  analyzing how many customers make it to each step


create temporary table lander1_thankyou
SELECT website_session_id,
 MAX(products) as products,MAX(fuzzy) as fuzzy,MAX(cart) as cart,MAX(shipping) as shipping,
 MAX(billing) as billing, MAX(thankyou) as thankyou
 
 FROM (

SELECT wp.website_session_id, wp.pageview_url , 

CASE WHEN wp.pageview_url = '/products' THEN 1 ELSE 0  END as products,
CASE WHEN wp.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0  END as fuzzy,
CASE WHEN wp.pageview_url = '/cart' THEN 1 ELSE 0  END as cart,
CASE WHEN wp.pageview_url = '/shipping' THEN 1 ELSE 0  END as shipping,
CASE WHEN wp.pageview_url = '/billing' THEN 1 ELSE 0  END as billing,
CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0  END as thankyou
FROM website_sessions ws
LEFT JOIN  website_pageviews wp
ON wp.website_session_id = ws.website_session_id
where wp.created_at > '2012-08-05' AND wp.created_at < '2012-09-05'
AND ws.utm_source = 'gsearch' AND ws.utm_campaign= 'nonbrand'

) AS a 
GROUP BY 1;

SELECT COUNT(website_session_id) AS sessions,
SUM(products) AS to_products,
SUM(fuzzy) as to_fuzzy,
SUM(cart) as to_cart,
SUM(shipping) as to_ship,
SUM(billing) as to_billing,
sum(thankyou)as to_thankyou
FROM lander1_thankyou;


SELECT 
SUM(products)/COUNT(website_session_id) as lander_click_rt,
SUM(fuzzy)/SUM(products) as product_click,
SUM(cart)/SUM(fuzzy) as fuzzy_click,
SUM(shipping)/SUM(cart) as cart_click,
SUM(billing)/SUM(shipping) as shipping_click,
sum(thankyou)/SUM(billing) as billing_click
FROM lander1_thankyou;

#Results : There are 3 pages which have less clickthrough rates namely,  lander, Mr. Fuzzy page and the billing page. Focus should be on improving the conversio rates from these pages.

#New billing page- Billing-2 is introduced. what % of sessions on those pages end up placing an order. 

SELECT  wp.website_session_id , wp.pageview_url,o.website_session_id  as order_session_id
FROM website_pageviews wp
LEFT JOIN orders o 
ON wp.website_session_id = o.website_session_id
WHERE wp.pageview_url in ('/billing', '/billing-2')
AND wp.created_at between '2012-09-10' and '2012-11-10';


SELECT pageview_url, COUNT(website_session_id) as sessions, COUNT(order_session_id) as orders,
COUNT(order_session_id)/COUNT(website_session_id) AS billing_order_rate
FROM sessions_orders
GROUP BY 1;

#Results: new version of the billing page is doing a much better job at converting customers.
#Increased the conversion rate from 45% to 62% , major improvement.






----Author - Eleni Bisioti , ELSTAT, Greece


----- THE NETHERLANDS
----- Port of Amsterdam
---- Create table amslocs_201703d2 for Port of Amsterdam
create table amslocs_201703d2 as select * from emsalocs_201703d2  
where lon>4.7298 and lon<4.8814 and lat>52.3878 and lat<52.4406;  

----  Create indexes and geometry point field (geom) from coordinates to table amslocs_201703d2 
create index ams_posindex  on amslocs_201703d2 (mmsi,lon,lat,rec_time);
alter table amslocs_201703d2 add column geom geometry(point,4326);
update amslocs_201703d2 set geom=ST_SetSRID(ST_MakePoint(lon,lat),4326);
create index geom_amsindex on amslocs_201703d2 using GIST(geom);
--Create  table amsmovements_201703d2   (by enriching  amslocs_201703d2  table) with fields that show 
-----previous (geom1) and next (geom2) position of a ship, 
-----time needed to cover the distance between the two positions (duration_secs), 
-----distance covered by the ship from position1 to position2 (dist)  

create table amsmovements_201703d2   as (	
SELECT
mmsi,day_when,start_ts,end_ts,geom1,geom2,lat1,lat2,lon1,lon2,
extract(epoch from (end_ts - start_ts)) AS duration_secs,
st_distance(st_transform(geom1, 28992), st_transform(geom2, 28992)) AS dist,
st_makeline(geom1,geom2)::geometry(LineString, 4326) AS geo_segment 
FROM
     (SELECT
      mmsi,date_trunc('day',rec_time)  as day_when,
      rec_time AS start_ts,
      lead(rec_time) OVER w AS end_ts,
      geom AS geom1,
      lead(geom) OVER w AS geom2,
      lat AS lat1,
      lead(lat) OVER w AS lat2,
      lon AS lon1,
      lead(lon) OVER w AS lon2
      FROM
      amslocs_201703d2 
      WINDOW w AS (PARTITION BY mmsi, date_trunc('day',rec_time) ORDER BY rec_time)
	 ) as q);


----- delete from table amsmovements_201703d2    records that show no movement 
delete from amsmovements_201703d2    where geom2 is null  or dist=0; --6445 records deleted

----Enrich table amsmovements_201703d2   with columns that show 
---the velocity (veloc), 
---the difference of latitude (diflat2lat1) and longitude (diflon2lon1) when a ship is moving from  position1 to position2 
alter table amsmovements_201703d2  
	add veloc numeric,
	add diflat2lat1 numeric,
	add diflon2lon1 numeric;
		
update amsmovements_201703d2  
 SET veloc=dist/duration_secs;
	
  update amsmovements_201703d2
  SET veloc=round(veloc,2);

update amsmovements_201703d2 
 SET diflat2lat1=(lat2-lat1)*1000;

 update amsmovements_201703d2 
 SET diflon2lon1=(lon2-lon1)*1000;

----Tanker terminals 
--- Create table and insert polygon areas – tanker  terminals  in port of Amsterdam
CREATE TABLE port_polys_ams (poly_id bigserial primary key, name text, geom geometry (polygon, 4326));


INSERT INTO port_polys_ams (name, geom)	
select 'ams10',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.73962	52.4265,
4.75198	52.4256,
4.75472	52.4099,
4.73928	52.4099,
4.73962	52.4265))',4326));

INSERT INTO port_polys_ams (name, geom)	
select 'ams20',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.76376	52.4247,
4.77738	52.4237,
4.80312	52.4107,
4.79935	52.399,
4.76788	52.4006,
4.76376	52.4247))',4326));

INSERT INTO port_polys_ams (name, geom)	
select 'ams30',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.80782	52.4154,
4.81869	52.4155,
4.82647	52.4079,
4.83356	52.4073,
4.83791	52.4051,
4.83665	52.3925,
4.80598	52.393,
4.80507	52.4003,
4.80782	52.4154))',4326));

INSERT INTO port_polys_ams (name, geom)	
select 'ams40',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.83825	52.4163,
4.84592	52.4154	,
4.85393	52.407,
4.84741	52.4029,
4.82967	52.4098,
4.83825	52.4163))',4326));

INSERT INTO port_polys_ams (name, geom)	
select 'ams50',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.85313	52.4149,
4.86102	52.413,
4.85753	52.4089,
4.85101	52.4119,
4.86305	52.4086,	
4.85313	52.4149))',4326));

INSERT INTO port_polys_ams (name, geom)	
select 'ams60',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.86294	52.408
4.86812	52.4096
4.87295	52.4053
4.86405	52.4023
4.86039	52.4055
4.86294	52.408))',4326));

----Tankers’ arrivals at 7/3/2017
---Query to find vessels (key value mmsi) inside tanker terminals for 6 and 7 March 2017: 
---Condition1 :  AIS ship type 80 (=tankers) . 
---Condition2 :  The tankers have to be moving (velocity>0.2) 
---Condition3 :  The tankers are arriving at the terminal so one previous position (geom1) is outside terminal 
---------------------and the following position (geom2) is inside the terminal
---Condition4 :  Filter out  inland waters’ vessels which do not have imo number. (IMO number should have 7 digits)
SELECT a.mmsi, a.day_when, a.start_ts, a.end_ts, 
        		                a.geom1, a.geom2, a.duration_secs, 
				a.dist, a.geo_segment, a.veloc, 
				pr.name,
				pr.geom,
	   			 v.vessel_name,
	  			  v.shiptype_ais
		      FROM  amsmovements_201703d2  a, 	---- movements table
	   		    port_polys_ams pr,			 ---- tanker terminals (polygons) table
	 		    emsaships_201703 v			 ---- vessels register (characteristics) table
				where 
	   		           v.mmsi=a.mmsi and
			          v.shiptype_ais='80' and			           --- AIS ship type 80 (=tankers)
			          length(v.imo)=7 and   	 		            --- Filter out  inland waters’ vessels
	  		          a.veloc>0.2 and 		             		            ---tankers are moving
			          st_contains(pr.geom, a.geom1) = false and	            ---Condition3
			         st_contains(pr.geom, a.geom2) = true                      ---Condition3
				order by a.mmsi,a.start_ts 


---Query selection of tankers (ais_type=80) that enter the terminals (polygon areas) on 7/3/2017 

select  al.t_mmsi, al.t_imo,al.t_name,al.day_observed 
from
  (SELECT
             ams_t.v_mmsi as t_mmsi,
             ams_t.v_imo as t_imo,
	 ams_t.v_name as t_name,
              ams_t.arrival_day AS day_observed,
             lead(ams_t.arrival_day) OVER w AS second_day,
             lag(ams_t.arrival_day) OVER w AS first_day
   FROM
     	(select b.mmsi as v_mmsi, b.imo as v_imo, b.vessel_name as v_name,b.day_when as arrival_day
                         from
		(SELECT a.mmsi, v.imo, a.day_when, a.start_ts, a.end_ts, 
        		                a.geom1, a.geom2, a.duration_secs, 
				a.dist, a.geo_segment, a.veloc, 
				pr.name,
				pr.geom,
	   			 v.vessel_name,
                                                            v.imo,
	  			  v.shiptype_ais
		            FROM  amsmovements_201703d2  a, 	---- movements table
	   		    port_polys_ams pr,			 ---- tanker terminals (polygons) table
	 		    emsaships_201703 v			 ---- vessels register (characteristics) table
				where 
	   		           v.mmsi=a.mmsi and
			          v.shiptype_ais='80' and			           --- AIS ship type 80 (=tankers)
			          length(v.imo)=7 and   	 		            --- Filter out  inland waters’ vessels
	  		          a.veloc>0.2 and 		             		            ---tankers are moving
			          st_contains(pr.geom, a.geom1) = false and	            ---Condition3
			         st_contains(pr.geom, a.geom2) = true                      ---Condition3
				order by a.mmsi,a.start_ts 
			) b
			group by b.mmsi, b.imo ,b.vessel_name,b.day_when
			order by b.mmsi,b.vessel_name,b.day_when
		)  ams_t 
    WINDOW w AS (PARTITION BY ams_t.v_mmsi ORDER BY ams_t.v_mmsi)
	) al
	where 
  	al.second_day is null and al.first_day  is null    ---exclude vessels observed at 6/3/2017
             and al.day_observed='2017-03-07 00:00:00'	


-----Port of Rotterdam
---- Create table rotslocs_201703d2 for Port of Rotterdam
create table rotlocs_201703d2 as select * from emsalocs_201703d2  
where lon>3.9491 and lon<4.4808 and lat>51.8695 and lat<51.9970;  

----  Create indexes and geometry point field (geom) from coordinates to table rotlocs_201703d2 
create index rot_posindex  on rotlocs_201703d2 (mmsi,lon,lat,rec_time);
alter table rotlocs_201703d2 add column geom geometry(point,4326);
update rotlocs_201703d2 set geom=ST_SetSRID(ST_MakePoint(lon,lat),4326);
create index geom_rotindex on rotlocs_201703d2 using GIST(geom);
--Create  table rotmovements_201703d2   (by enriching  rotlocs_201703d2  table) with fields that show 
-----previous (geom1) and next (geom2) position of a ship, 
-----time needed to cover the distance between the two positions (duration_secs), 
-----distance covered by the ship from position1 to position2 (dist)  

create table rotmovements_201703d2   as (	
SELECT
mmsi,day_when,start_ts,end_ts,geom1,geom2,lat1,lat2,lon1,lon2,
extract(epoch from (end_ts - start_ts)) AS duration_secs,
st_distance(st_transform(geom1, 28992), st_transform(geom2, 28992)) AS dist,
st_makeline(geom1,geom2)::geometry(LineString, 4326) AS geo_segment 
FROM
     (SELECT
      mmsi,date_trunc('day',rec_time)  as day_when,
      rec_time AS start_ts,
      lead(rec_time) OVER w AS end_ts,
      geom AS geom1,
      lead(geom) OVER w AS geom2,
      lat AS lat1,
      lead(lat) OVER w AS lat2,
      lon AS lon1,
      lead(lon) OVER w AS lon2
      FROM
      rotlocs_201703d2 
      WINDOW w AS (PARTITION BY mmsi, date_trunc('day',rec_time) ORDER BY rec_time)
	 ) as q);


----- delete from table rotmovements_201703d2    records that show no movement 
delete from rotmovements_201703d2    where geom2 is null  or dist=0; --25188  records deleted

----Enrich table rotmovements_201703d2   with columns that show 
---the velocity (veloc), 
---the difference of latitude (diflat2lat1) and longitude (diflon2lon1) when a ship is moving from  position1 to position2 
alter table rotmovements_201703d2  
	add veloc numeric,
	add diflat2lat1 numeric,
	add diflon2lon1 numeric;
		
update rotmovements_201703d2  
 SET veloc=dist/duration_secs;
	
  update rotmovements_201703d2
  SET veloc=round(veloc,2);

update rotmovements_201703d2 
 SET diflat2lat1=(lat2-lat1)*1000;

 update rotmovements_201703d2 
 SET diflon2lon1=(lon2-lon1)*1000;

---Insert to port_polys table terminal polygon for Rotterdam using coordinates
INSERT INTO port_polys (name, geom)					
SELECT 'rotterdam',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((3.9491 51.9970,
4.4808 51.9970,
4.4808 51.8695,
3.9491 51.8695,
3.9491 51.9970))',4326));

---Insert to port_polys table a test (small polygon)  terminal polygon using coordinates
INSERT INTO port_polys (name, geom)					
SELECT 'rot_poly1',
ST_BuildArea (ST_GEOMFROMTEXT('polygon((4.06879 51.97586,
4.09591 51.95610,
4.09695 51.93344,
4.03072 51.92459,
3.96187 51.95787,
3.98925 51.98534,
4.03332 51.98486,
4.06879 51.97586
 ))',4326));

------Test of movements in 'rot_poly1' (small polygon)
SELECT a.mmsi, a.day_when, a.start_ts, a.end_ts, 
        a.geom1, a.geom2, a.lat1, a.lat2, a.lon1, a.lon2, a.duration_secs, 
		a.dist, a.geo_segment, a.veloc, a.diflat2lat1, a.diflon2lon1,
		pr.name,
		pr.geom
FROM rotmovements_201703d2 a, 
	    port_polys pr

where 
pr.name='rot_poly1' and						  
a. day_when='2017-03-06 00:00:00' and
a.veloc>0.7 and
 st_contains(pr.geom, a.geom2) = true 
order by a.mmsi,a.start_ts;

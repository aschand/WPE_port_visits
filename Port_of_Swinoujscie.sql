
----Author - Eleni Bisioti , ELSTAT, Greece


------- POLAND, Port of Świnoujście 
---- Create table swinlocs_201703d2 for Port of Świnoujście with code:
create table swinlocs_201703d2 as select * from emsalocs_201703d2  
where lon>14.250708 and lon<14.286217 and lat>53.88011 and lat<53.951968;  

----  Create indexes and geometry point field (geom) from coordinates to table swinlocs_201703d2 
create index swin_posindex  on swinlocs_201703d2 (mmsi,lon,lat,rec_time);

alter table swinlocs_201703d2 add column geom geometry(point,4326);

update swinlocs_201703d2 set geom=ST_SetSRID(ST_MakePoint(lon,lat),4326);

create index geom_swinindex on swinlocs_201703d2 using GIST(geom);

--Create  table swinmovements_201703d2   (by enriching  swinlocs_201703d2  table) with fields that show 
-----previous (geom1) and next (geom2) position of a ship, 
-----time needed to cover the distance between the two positions (duration_secs), 
-----distance covered by the ship from position1 to position2 (dist)  
create table swinmovements_201703d2   as (	
SELECT
mmsi,day_when,start_ts,end_ts,geom1,geom2,lat1,lat2,lon1,lon2,
extract(epoch from (end_ts - start_ts)) AS duration_secs,
st_distance(st_transform(geom1, 28992), st_transform(geom2, 28992)) AS dist,
st_makeline(geom1,geom2)::geometry(LineString, 4326) AS geo_segment 
FROM (SELECT
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
      swinlocs_201703d2 
      WINDOW w AS (PARTITION BY mmsi, date_trunc('day',rec_time) ORDER BY rec_time)
	 ) as q);

----- delete from table swinmovements_201703d2    records that show no movement 
delete from swinmovements_201703d2    where geom2 is null  or dist=0; --2003 records deleted
----Enrich table swinmovements_201703d2   with columns that show 
---the velocity (veloc), 
---the difference of latitude (diflat2lat1) and longitude (diflon2lon1) when a ship is traveling from  position1 to position2 
alter table swinmovements_201703d2  
	add veloc numeric,
	add diflat2lat1 numeric,
	add diflon2lon1 numeric;
		
update swinmovements_201703d2  
 SET veloc=dist/duration_secs;
	
  update swinmovements_201703d2
  SET veloc=round(veloc,2);

update swinmovements_201703d2 
 SET diflat2lat1=(lat2-lat1)*1000;

 update swinmovements_201703d2 
 SET diflon2lon1=(lon2-lon1)*1000;
			
----Selection of ships arriving at the port of Świnoujście 
select * from swinmovements_201703d2  
where 
 veloc>0 and 
(diflat2lat1 between -1000 and 0) and  		-------lat2<lat1 approaching to port entrance
(diflon2lon1 between -1000 and 1000) and 	------ default values
(lon1 between -1000 and 1000) and   		------ default values
(lon2 between -1000 and 1000) and 		------ default values
(lat1 between 53.9220 and 53.9550 ) and           ------ latitude of position 1 until the entrance of the port
 (lat2 between 53.90 and 53.9219) 	             ------ latitude of position 2 entering the port
order by mmsi, start_ts

---Number of arrivals per ship (mmsi) for the  port of Świnoujście 
select mmsi, count(mmsi) as arrivals from swinmovements_201703d2  
where 
veloc>0 and 
(diflat2lat1 between -1000 and 0) and  		-------lat2<lat1 approaching to port entrance
(diflon2lon1 between -1000 and 1000) and 	------ default values
(lon1 between -1000 and 1000) and   		------ default values
(lon2 between -1000 and 1000) and 		------ default values
(lat1 between 53.9220 and 53.9550 ) and           ------ latitude of position 1 until the entrance of the port
 (lat2 between 53.90 and 53.9219) 	             ------ latitude of position 2 entering the port
  group by mmsi order by mmsi;

------------Link the above query to table emsaships_201703  to enrich results with the available vessels’ characteristics (from AIS data)
select 
 a.mmsi , a.arrivals,
 b.imo, b.vessel_name, b.shiptype_ais,b.s_length,b.s_width
 from 
   (select mmsi, count(mmsi) as arrivals from swinmovements_201703d2  
    where 
    veloc>0 and 
    (diflat2lat1 between -1000 and 0) and  -------lat2<lat1 approaching to port entrance
    (diflon2lon1 between -1000 and 1000) and ------ default values
    (lon1 between -1000 and 1000) and   ------ default values
    (lon2 between -1000 and 1000) and ------ default values
    (lat1 between 53.9220 and 53.9550 ) and  ------ latitude of position 1 until the entrance of the port
    (lat2 between 53.90 and 53.9219)  ------ latitude of position 2 entering the port
     group by mmsi order by mmsi) a, 
   emsaships_201703 b
 where a.mmsi=b.mmsi
order by a.mmsi

------------Alter table emsaships_201703 add fields for ship type (shiptype_2d), description of ship type( shiptype_2d_per), 
------- gross tonnage (gross_ton), gross tonnage kategory (gross_ton_klim ) according to Directive 
alter table emsaships_201703
	add shiptype_2d numeric,
	add  shiptype_2d_per character varying ,
	add  gross_ton numeric,
 	add  gross_ton_klim character varying ;

-----Create temporary table tmp_x  to upload csv file with characteristics for ship type (shiptype_2d), description of ship type( shiptype_2d_per),
------gross tonnage (gross_ton), gross tonnage kategory (gross_ton_klim ) according to Directive for the above selected mmsi’s
CREATE TABLE tmp_x (mmsi character varying, shiptype_2d_per character varying,gross_ton numeric,shiptype_2d numeric);
    
---Csv file contains the following information for mmsi,shiptype_2dper,gross_ton, shiptype_2d
------------Update ships table emsaships_201703 from temporary table
UPDATE public.emsaships_201703
SET  shiptype_2d=tmp_x.shiptype_2d, shiptype_2d_per=tmp_x.shiptype_2d_per,  gross_ton=tmp_x.gross_ton
FROM public.tmp_x
WHERE emsaships_201703.mmsi=tmp_x.mmsi;	
------------View the updated records
select * from public.emsaships_201703 where shiptype_2d_per is not null;

---------------------update field  gross_ton_klim of ships table emsaships_201703  according to Directive size classes using gross_ton
UPDATE 	emsaships_201703		
SET gross_ton_klim = (CASE WHEN gross_ton BETWEEN 100 AND 499 THEN ' 1  (from 100 to 499 GT) ' 
		                    WHEN gross_ton BETWEEN 500 AND 999 THEN ' 2  (from 500 to 999 GT) ' 
		                    WHEN gross_ton BETWEEN 1000 AND 1999 THEN ' 3  (from 1 000 to 1 999 GT)' 
		                    WHEN gross_ton BETWEEN 2000 AND 2999 THEN ' 4  (from 2 000 to 2 999 GT)' 
		                    WHEN gross_ton BETWEEN 3000 AND 3999 THEN ' 5  (from 3 000 to 3 999 GT)' 
		                    WHEN gross_ton BETWEEN 4000 AND 4999 THEN ' 6  (from 4 000 to 4 999 GT)' 
		                    WHEN gross_ton BETWEEN 5000 AND 5999 THEN ' 7  (from 5 000 to 5 999 GT)' 
		                    WHEN gross_ton BETWEEN 6000 AND 6999 THEN ' 8  (from 6 000 to 6 999 GT)' 
		                    WHEN gross_ton BETWEEN 7000 AND 7999 THEN ' 9  (from 7 000 to 7 999 GT)' 
		                    WHEN gross_ton BETWEEN 8000 AND 8999 THEN ' 10 (from 8 000 to 8 999 GT)' 
		                    WHEN gross_ton BETWEEN 9000 AND 9999 THEN ' 11 (from 9 000 to 9 999 GT)' 
		                    WHEN gross_ton BETWEEN 10000 AND 19999 THEN ' 12 (from 10 000 to 19 999 GT)' 
		                    WHEN gross_ton BETWEEN 20000 AND 29999 THEN ' 13 (from 20 000 to 29 999 GT)' 
		                    WHEN gross_ton BETWEEN 30000 AND 39999 THEN ' 14 (from 30 000 to 39 999 GT)' 
		                    WHEN gross_ton BETWEEN 40000 AND 49999 THEN ' 15 (from 40 000 to 49 999 GT)' 
		                    WHEN gross_ton BETWEEN 50000 AND 79999 THEN ' 16 (from 50 000 to 79 999 GT)' 
		                    WHEN gross_ton BETWEEN 80000 AND 99999 THEN ' 17 (from 80 000 to 99 999 GT)' 
		                    WHEN gross_ton BETWEEN 100000 AND 149999 THEN ' 18 (from 100 000 to 149 999 GT)' 
		                    WHEN gross_ton BETWEEN 150000 AND 199999 THEN ' 19 (from 150 000 to 199 999 GT)' 
		                    WHEN gross_ton BETWEEN 200000 AND 249999 THEN ' 20 (from 200 000 to 249 999 GT)' 
		                    WHEN gross_ton BETWEEN 250000 AND 299999 THEN ' 21 (from 250 000 to 299 999 GT)' 
		                    WHEN gross_ton BETWEEN 300000 AND 300000000000000 THEN ' 22 ( ≥ 300 000  GT)' 
		                    					  END) ;						

------------View the updated records 
select * from public.emsaships_201703 where gross_ton_klim is not null;
------------View the updated records of interest (shiptype_2d has value only for maritime ships of interest)
select * from public.emsaships_201703 where shiptype_2d is not null;
----------- Number of arrivals per ship (mmsi) for the  port of Świnoujście - enriched results with vessels’ characteristics  (according to Directive)
------keeping ship types of interest
select 
 a.mmsi , a.arrivals, b.shiptype_2d, b.shiptype_2d_per, b.gross_ton, b.gross_ton_klim
 from 
   (select mmsi, count(mmsi) as arrivals from swinmovements_201703d2  
    where 
    veloc>0 and 
    (diflat2lat1 between -1000 and 0) and  -------lat2<lat1 approaching to port entrance
    (diflon2lon1 between -1000 and 1000) and ------ default values
    (lon1 between -1000 and 1000) and   ------ default values
    (lon2 between -1000 and 1000) and ------ default values
    (lat1 between 53.9220 and 53.9550 ) and  ------ latitude of position 1 until the entrance of the port
    (lat2 between 53.90 and 53.9219)  ------ latitude of position 2 entering the port
     group by mmsi order by mmsi) a, 
   emsaships_201703 b
 where a.mmsi=b.mmsi and b.shiptype_2d is not null
order by a.mmsi

----F2 table for the port of Świnoujście

select f.shiptype_2d||'-'||f.shiptype_2d_per as "Type", f.gross_ton_klim as "Size class", sum(f.arrivals) as "Total number of vessels (arrivals)",  sum(f.arrivals*f.gross_ton) as "Total weight (in GT)" 
from
(
select 
 a.mmsi , a.arrivals,b.shiptype_2d, b.shiptype_2d_per, b.gross_ton, b.gross_ton_klim
 from 
   (select mmsi, count(mmsi) as arrivals from swinmovements_201703d2  
    where 
    veloc>0 and 
    (diflat2lat1 between -1000 and 0) and  -------lat2<lat1 approaching to port entrance
    (diflon2lon1 between -1000 and 1000) and ------ default values
    (lon1 between -1000 and 1000) and   ------ default values
    (lon2 between -1000 and 1000) and ------ default values
    (lat1 between 53.9220 and 53.9550 ) and  ------ latitude of position 1 until the entrance of the port
    (lat2 between 53.90 and 53.9219)  ------ latitude of position 2 entering the port
     group by mmsi order by mmsi) a, 
   emsaships_201703 b
 where a.mmsi=b.mmsi and b.shiptype_2d is not null
order by a.mmsi
)f
group by f.shiptype_2d,f.gross_ton_klim, f.shiptype_2d_per
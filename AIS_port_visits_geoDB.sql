
----Author - Eleni Bisioti , ELSTAT, Greece

--------- Create BASIC tables emsalocs_201703d2  and emsaships_201703 and upload AIS data from csv files 
CREATE TABLE emsalocs_201703d2
(
   rec_time timestamp without time zone,
    mmsi character varying ,
    msgtype character varying ,
    lat double precision,
    lon double precision,
    rot numeric,
    sog numeric,
    cog numeric,
    heading character varying ,
    navstatus character varying ,
    draught character varying ,
    eta character varying ,
    destination character varying );

CREATE TABLE emsaships_201703
(
    mmsi character varying ,
    imo character varying ,
    msgtype character varying ,
    vessel_name character varying ,
    callsign character varying ,
    shiptype_ais character varying,
    s_length numeric,
    s_width numeric);

---- count number of records of emsalocs_201703d2 table
select count(*) from emsalocs_201703d2;
---- count number of records of emsaships_201703 table
select count(*) from emsaships_201703;

---- Field MMSI has 9 digits . Delete records with wrong number of digits for mmsi with code:
delete from emsalocs_201703d2
where length(mmsi)<9 or length(mmsi)>9;  --28843 records deleted

----The first digit of MMSI  is a number from 2 to 7 and indicates the vessel’s continent 2=Europe, 3=North or 
-----Central America, Caribbean, 4=Asia, 5=Oceania, 6=Africa, 7=South America) .
delete  from emsalocs_201703d2
where to_number(mmsi,'9')<2 or to_number(mmsi,'9')>7; ---20987 records deleted


----- Create table pirlocs_201703d2 for Port of Piraeus
create table pirlocs_201703d2 as select * from emsalocs_201703d2  
where 
lon>23.499 and lon<23.8701 and lat>37.6081 and lat<37.9714;  

----- Create table swinlocs_201703d2 for Port of Świnoujście
create table swinlocs_201703d2 as select * from emsalocs_201703d2  
where 
lon>14.250708 and lon<14.286217 and lat>53.88011 and lat<53.951968;  

----- Create table amslocs_201703d2 for Port of Amsterdam
create table amslocs_201703d2 as select * from emsalocs_201703d2  
where 
lon>4.7298 and lon<4.8814 and lat>52.3878 and lat<52.4406;  

----- Create table amslocs_201703d2 for Port of Rotterdam
create table rotlocs_201703d2 as select * from emsalocs_201703d2  
where lon>3.9491 and lon<4.4808 and lat>51.8695 and lat<51.9970;  




# WPE_port_visits

----Author - Eleni Bisioti , ELSTAT, Greece

Creation of a  spatio-temporal database (DB) of ships movements, using AIS data

The DB is implemented in PostgreSQL with PostGIS in a Database Instance named estatdsl2531 on EC Dataplatform. 
Can be also deployed in a standalone computer or server. 
Prerequisites are the installation of PostgreSQL with PostGIS extention and PgAdmin. 
Developer/user should have basic skills on SQL Databases, understanding and running sql scripts , 
be familiar with AIS ships position reports (decoded AIS messages 1,2,3) , AIS static and voyage data (decoded AIS message 5) and working with coordinates on maps . 

The added value of Spatio-temporal select queries is that one gets results interactively, 
positions and distances of moving vessels, due to  geometry  viewer, are placed on map without an extra visualization tool, 
fields connecting two events with different timestamps as for example previous and next position of a ship are supported in the same record , 
tables with geometric shapes as records can be created  

---	Set up SSL connection to EC Dataplatform for PostgreSQL Database
           Before connecting to PostgreSQL Database, an SSL connection to EC Dataplatform has to be set up, following the steps below 
1.	Invoke Command Prompt to your computer.
2.	Change to drive C: ( Write c: , press Enter)
3.	Write the command :
ssh  your_username@34.254.164.77 -L 127.0.0.1:54322:ed1ee5b82d3innd.cqurug5ll20q.eu-west-1.rds.amazonaws.com:5432 

Give your_password  (EC Dataplatform password)
Then, minimize this screen (Do not exit or close it) and  proceed launching PgAdmin

---- Install pgAdmin from http://www.pgadmin.org/. You can download and use pgAdmin without having a local instance of PostgreSQL on your client computer.
1.	Launch the pgAdmin application on your client computer.
2.	Choose Add Server from the File menu.
Click on Add New Server 
Name: AIS_admin 
Choose second Tab (Connection)
Enter required information
Host name/address : 127.0.0.1
Port : 54322
Username: AIS_admin
Password: ******
 and save.

-------Basic tables of the database : 
emsalocs_201703d2 , which contains two days (6/3/2017 to 7/3/2017)  decoded AIS messages 1,2,3 from EMSA uploaded from csv files Each csv file contains data about the following fields, 
rec_time; mmsi; msgtype;lat; lon; rot; sog; cog; heading; navstatus;draught;eta;destination
which looks like that
2017-03-06T00:00:00;205202190;1;51.282003;4.367547;;0;320.8;;0;;;
2017-03-06T00:00:00;211211520;3;55.135915;12.64623;-720;10.6;174.5;169;0;;;
2017-03-06T00:00:00;211214670;1;53.475818;9.956457;;0;;;0;;;

emsaships_201703 which contains one month (1/3/2017 to 31/3/2017)  AIS static (decoded AIS message 5) from EMSA uploaded from csv files Each csv file contains data about the following fields,
mmsi; msgtype;imo;vessel_name;callsign;shiptype_ais;v_length;v_width
which looks like that
229929000;5;9708875;AL ZUBARA;9HA3726;71;400;59
230202000;5;8503503;STEEL;OIVR;70;167;27

https://github.com/AIS-data/WPE_port_visits/blob/master/AIS_port_visits_geoDB.sql

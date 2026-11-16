-- MariaDB dump 10.19  Distrib 10.4.24-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: yusr_application
-- ------------------------------------------------------
-- Server version	10.4.24-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `admin`
--

DROP TABLE IF EXISTS `admin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin` (
  `Admin_ID` int(11) NOT NULL,
  `A_Name` varchar(100) DEFAULT NULL,
  `A_Email` varchar(100) DEFAULT NULL,
  `A_Number` varchar(20) DEFAULT NULL,
  `A_password` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Admin_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin`
--

LOCK TABLES `admin` WRITE;
/*!40000 ALTER TABLE `admin` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `appointments`
--

DROP TABLE IF EXISTS `appointments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `appointments` (
  `Appointment_ID` int(11) NOT NULL,
  `A_Time` time DEFAULT NULL,
  `A_Date` date DEFAULT NULL,
  `A_DateType` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `A_Location` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `A_Note` mediumtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Appointment_ID`),
  KEY `Elderly_ID` (`Elderly_ID`),
  CONSTRAINT `appointments_ibfk_1` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `appointments`
--

LOCK TABLES `appointments` WRITE;
/*!40000 ALTER TABLE `appointments` DISABLE KEYS */;
/*!40000 ALTER TABLE `appointments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `caregivers`
--

DROP TABLE IF EXISTS `caregivers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `caregivers` (
  `Caregivers_ID` int(11) NOT NULL,
  `C_Name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `C_PhonNumber` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `C_Relationship` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `C_Email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `C_Password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Eldery_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Caregivers_ID`),
  KEY `Eldery_ID` (`Eldery_ID`),
  CONSTRAINT `caregivers_ibfk_1` FOREIGN KEY (`Eldery_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `caregivers`
--

LOCK TABLES `caregivers` WRITE;
/*!40000 ALTER TABLE `caregivers` DISABLE KEYS */;
INSERT INTO `caregivers` VALUES (1,'عبدالله سالم','771234567','ابن','caregiver@yusr.com',NULL,1),(2,'شهد حسين','777123456','ابنة','shahdhuss777@gmail.com','2345',NULL),(3,'شهد الكربي','739871110','ابنه','shahdhussein@gmail.com','11111',NULL);
/*!40000 ALTER TABLE `caregivers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `devices`
--

DROP TABLE IF EXISTS `devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `devices` (
  `Devices_ID` int(11) NOT NULL,
  `D_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `T_Number` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Devices_ID`),
  KEY `Elderly_ID` (`Elderly_ID`),
  CONSTRAINT `devices_ibfk_1` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `devices`
--

LOCK TABLES `devices` WRITE;
/*!40000 ALTER TABLE `devices` DISABLE KEYS */;
INSERT INTO `devices` VALUES (1,'ساعة ذكية','ساعة يُسر الذكية V3',2);
/*!40000 ALTER TABLE `devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `education_content`
--

DROP TABLE IF EXISTS `education_content`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `education_content` (
  `Content_ID` int(11) NOT NULL,
  `Content_Title` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Content_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Content_Image` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Content_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Publish_Date` date DEFAULT NULL,
  `Admin_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Content_ID`),
  KEY `Admin_ID` (`Admin_ID`),
  CONSTRAINT `education_content_ibfk_1` FOREIGN KEY (`Admin_ID`) REFERENCES `admin` (`Admin_ID`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `education_content`
--

LOCK TABLES `education_content` WRITE;
/*!40000 ALTER TABLE `education_content` DISABLE KEYS */;
/*!40000 ALTER TABLE `education_content` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `elderly`
--

DROP TABLE IF EXISTS `elderly`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `elderly` (
  `Eldery_ID` int(11) NOT NULL,
  `E_Name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `E_sex` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `E_PhonNumber` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `E_Email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `E_Password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Eldery_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `elderly`
--

LOCK TABLES `elderly` WRITE;
/*!40000 ALTER TABLE `elderly` DISABLE KEYS */;
INSERT INTO `elderly` VALUES (1,'سالم محمد','ذكر','0501234567','senior@yusr.com',NULL),(2,'علي احمد','ذكر','7712345','ali@gmail.com','33333');
/*!40000 ALTER TABLE `elderly` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emergency_contacts`
--

DROP TABLE IF EXISTS `emergency_contacts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `emergency_contacts` (
  `contact_ID` int(11) NOT NULL,
  `contact_Name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Phone_Number` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Relationship` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Priority` int(11) DEFAULT NULL,
  `Eldery_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`contact_ID`),
  KEY `Eldery_ID` (`Eldery_ID`),
  CONSTRAINT `emergency_contacts_ibfk_1` FOREIGN KEY (`Eldery_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emergency_contacts`
--

LOCK TABLES `emergency_contacts` WRITE;
/*!40000 ALTER TABLE `emergency_contacts` DISABLE KEYS */;
/*!40000 ALTER TABLE `emergency_contacts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emergency_log`
--

DROP TABLE IF EXISTS `emergency_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `emergency_log` (
  `Emergency_ID` int(11) NOT NULL,
  `E_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `E_Date` date DEFAULT NULL,
  `E_Time` time DEFAULT NULL,
  `E_Location` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,8) DEFAULT NULL,
  `Longitude` decimal(11,8) DEFAULT NULL,
  `E_State` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Descripion` mediumtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Emergency_ID`),
  KEY `Elderly_ID` (`Elderly_ID`),
  CONSTRAINT `emergency_log_ibfk_1` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emergency_log`
--

LOCK TABLES `emergency_log` WRITE;
/*!40000 ALTER TABLE `emergency_log` DISABLE KEYS */;
INSERT INTO `emergency_log` VALUES (1,'???? ??????? ???? SOS','2026-10-17','02:43:44','?? ????????? ??????',NULL,NULL,'تمت المعالجة','?? ??????? ?? ????? ???? ?? ????? ????',1);
/*!40000 ALTER TABLE `emergency_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `health_alerts`
--

DROP TABLE IF EXISTS `health_alerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `health_alerts` (
  `Alert_ID` int(11) NOT NULL,
  `A_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `A_Description` mediumtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `A_Level` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `A_Date` date DEFAULT NULL,
  `A_Status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `H_Record_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Alert_ID`),
  KEY `H_Record_ID` (`H_Record_ID`),
  CONSTRAINT `health_alerts_ibfk_1` FOREIGN KEY (`H_Record_ID`) REFERENCES `health_monitoring` (`H_Record_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `health_alerts`
--

LOCK TABLES `health_alerts` WRITE;
/*!40000 ALTER TABLE `health_alerts` DISABLE KEYS */;
/*!40000 ALTER TABLE `health_alerts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `health_monitoring`
--

DROP TABLE IF EXISTS `health_monitoring`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `health_monitoring` (
  `H_Record_ID` int(11) NOT NULL,
  `Heart_Rate` int(11) DEFAULT NULL,
  `Blood_pressure` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Oxyger` int(11) DEFAULT NULL,
  `Temperature` decimal(4,2) DEFAULT NULL,
  `steps` int(11) DEFAULT NULL,
  `H_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `H_Date` date DEFAULT NULL,
  `H_Result` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  `Devices_ID` int(11) DEFAULT NULL,
  `Emergency_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`H_Record_ID`),
  KEY `Elderly_ID` (`Elderly_ID`),
  KEY `Devices_ID` (`Devices_ID`),
  KEY `FK_Health_Emergency` (`Emergency_ID`),
  CONSTRAINT `FK_Health_Emergency` FOREIGN KEY (`Emergency_ID`) REFERENCES `emergency_log` (`Emergency_ID`) ON DELETE SET NULL,
  CONSTRAINT `health_monitoring_ibfk_1` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE,
  CONSTRAINT `health_monitoring_ibfk_2` FOREIGN KEY (`Devices_ID`) REFERENCES `devices` (`Devices_ID`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `health_monitoring`
--

LOCK TABLES `health_monitoring` WRITE;
/*!40000 ALTER TABLE `health_monitoring` DISABLE KEYS */;
/*!40000 ALTER TABLE `health_monitoring` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `location_alerts`
--

DROP TABLE IF EXISTS `location_alerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `location_alerts` (
  `Alert_ID` int(11) NOT NULL,
  `LA_State` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `LA_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Alert_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `location_alerts`
--

LOCK TABLES `location_alerts` WRITE;
/*!40000 ALTER TABLE `location_alerts` DISABLE KEYS */;
/*!40000 ALTER TABLE `location_alerts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `location_tracking`
--

DROP TABLE IF EXISTS `location_tracking`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `location_tracking` (
  `Location_ID` int(11) NOT NULL,
  `L_Latitude` decimal(10,8) DEFAULT NULL,
  `L_Longitude` decimal(11,8) DEFAULT NULL,
  `L_UpdateTime` datetime DEFAULT NULL,
  `L_Scor` int(11) DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Location_ID`),
  KEY `Elderly_ID` (`Elderly_ID`),
  CONSTRAINT `location_tracking_ibfk_1` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `location_tracking`
--

LOCK TABLES `location_tracking` WRITE;
/*!40000 ALTER TABLE `location_tracking` DISABLE KEYS */;
/*!40000 ALTER TABLE `location_tracking` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `medications`
--

DROP TABLE IF EXISTS `medications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `medications` (
  `Medicayion_ID` int(11) NOT NULL,
  `M_Name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `M_much` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `M_RepatTime` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Medicayion_ID`),
  KEY `Elderly_ID` (`Elderly_ID`),
  CONSTRAINT `medications_ibfk_1` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `medications`
--

LOCK TABLES `medications` WRITE;
/*!40000 ALTER TABLE `medications` DISABLE KEYS */;
/*!40000 ALTER TABLE `medications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `Notifications_ID` int(11) NOT NULL,
  `N_Title` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `N_Message` mediumtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `N_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `N_Date` date DEFAULT NULL,
  `N_Time` time DEFAULT NULL,
  `N_Status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Caregiver_ID` int(11) DEFAULT NULL,
  `Eldery_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Notifications_ID`),
  KEY `Caregiver_ID` (`Caregiver_ID`),
  KEY `Eldery_ID` (`Eldery_ID`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`Caregiver_ID`) REFERENCES `caregivers` (`Caregivers_ID`) ON DELETE CASCADE,
  CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`Eldery_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,'🚨 نداء طوارئ SOS عاجل!','???? ??????? ???? SOS: ?? ??? ?? ????????? SOS ?? ?????? في ?? ????????? ??????','emergency','2026-10-17','02:43:44','unread',NULL,1);
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reminders`
--

DROP TABLE IF EXISTS `reminders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reminders` (
  `Reminder_ID` int(11) NOT NULL,
  `R_title` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `R_date` date DEFAULT NULL,
  `R_time` time DEFAULT NULL,
  `Appointment_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Reminder_ID`),
  KEY `Appointment_ID` (`Appointment_ID`),
  CONSTRAINT `reminders_ibfk_1` FOREIGN KEY (`Appointment_ID`) REFERENCES `appointments` (`Appointment_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reminders`
--

LOCK TABLES `reminders` WRITE;
/*!40000 ALTER TABLE `reminders` DISABLE KEYS */;
/*!40000 ALTER TABLE `reminders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `safe_zones`
--

DROP TABLE IF EXISTS `safe_zones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `safe_zones` (
  `Zone_ID` int(11) NOT NULL,
  `Z_Name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Z_state` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Z_Limit` int(11) DEFAULT NULL,
  `Alert_ID` int(11) DEFAULT NULL,
  `Location_ID` int(11) DEFAULT NULL,
  `Zldery_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Zone_ID`),
  KEY `Alert_ID` (`Alert_ID`),
  KEY `Location_ID` (`Location_ID`),
  KEY `Zldery_ID` (`Zldery_ID`),
  CONSTRAINT `safe_zones_ibfk_1` FOREIGN KEY (`Alert_ID`) REFERENCES `location_alerts` (`Alert_ID`) ON DELETE SET NULL,
  CONSTRAINT `safe_zones_ibfk_2` FOREIGN KEY (`Location_ID`) REFERENCES `location_tracking` (`Location_ID`) ON DELETE CASCADE,
  CONSTRAINT `safe_zones_ibfk_3` FOREIGN KEY (`Zldery_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `safe_zones`
--

LOCK TABLES `safe_zones` WRITE;
/*!40000 ALTER TABLE `safe_zones` DISABLE KEYS */;
/*!40000 ALTER TABLE `safe_zones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `services`
--

DROP TABLE IF EXISTS `services`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `services` (
  `Service_ID` int(11) NOT NULL,
  `S_Name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `S_Type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `S_Description` mediumtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `S_Status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Admin_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Service_ID`),
  KEY `Admin_ID` (`Admin_ID`),
  CONSTRAINT `services_ibfk_1` FOREIGN KEY (`Admin_ID`) REFERENCES `admin` (`Admin_ID`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `services`
--

LOCK TABLES `services` WRITE;
/*!40000 ALTER TABLE `services` DISABLE KEYS */;
INSERT INTO `services` VALUES (1,'رعاية صحية وتمريضية منزلية','صحي','زيارات تمريضية دورية لمتابعة المؤشرات الحيوية وإعطاء الأدوية والحقن ورعاية الجروح.','نشط',NULL),(2,'مرافقة شخصية وإشراف','مرافقة','مرافقة يومية لكبير السن في المشاوير، مواعيد المستشفيات والأنشطة الاجتماعية.','نشط',NULL),(3,'علاج طبيعي وتأهيل حركي','تأهيل','جلسات علاج طبيعي وتمارين تنشيطية لكبار السن داخل المنزل مع أخصائيين معتمدين.','نشط',NULL),(4,'توصيل ونقل طبي آمن','نقل','سيارات مجهزة لنقل كبار السن وذوي الاحتياجات للمستشفيات والعيادات بأمان تام.','نشط',NULL),(5,'تغذية وإعداد وجبات صحية','تغذية','برامج غذائية مخصصة لحالات السكري والضغط وتحضير وجبات صحية متوازنة.','نشط',NULL);
/*!40000 ALTER TABLE `services` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `services_request`
--

DROP TABLE IF EXISTS `services_request`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `services_request` (
  `Service_Requst_ID` int(11) NOT NULL,
  `Requst_Date` date DEFAULT NULL,
  `Requst_Status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Requst_Note` mediumtext COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Service_ID` int(11) DEFAULT NULL,
  `Caregivers_id` int(11) DEFAULT NULL,
  `Elderly_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Service_Requst_ID`),
  KEY `Service_ID` (`Service_ID`),
  KEY `Caregivers_id` (`Caregivers_id`),
  KEY `Elderly_ID` (`Elderly_ID`),
  CONSTRAINT `services_request_ibfk_1` FOREIGN KEY (`Service_ID`) REFERENCES `services` (`Service_ID`) ON DELETE CASCADE,
  CONSTRAINT `services_request_ibfk_2` FOREIGN KEY (`Caregivers_id`) REFERENCES `caregivers` (`Caregivers_ID`) ON DELETE CASCADE,
  CONSTRAINT `services_request_ibfk_3` FOREIGN KEY (`Elderly_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `services_request`
--

LOCK TABLES `services_request` WRITE;
/*!40000 ALTER TABLE `services_request` DISABLE KEYS */;
/*!40000 ALTER TABLE `services_request` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `type_of_care`
--

DROP TABLE IF EXISTS `type_of_care`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `type_of_care` (
  `Tc_id` int(11) NOT NULL,
  `Care_Type` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Caregivers_ID` int(11) DEFAULT NULL,
  `Eldery_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`Tc_id`),
  KEY `Caregivers_ID` (`Caregivers_ID`),
  KEY `Eldery_ID` (`Eldery_ID`),
  CONSTRAINT `type_of_care_ibfk_1` FOREIGN KEY (`Caregivers_ID`) REFERENCES `caregivers` (`Caregivers_ID`) ON DELETE CASCADE,
  CONSTRAINT `type_of_care_ibfk_2` FOREIGN KEY (`Eldery_ID`) REFERENCES `elderly` (`Eldery_ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `type_of_care`
--

LOCK TABLES `type_of_care` WRITE;
/*!40000 ALTER TABLE `type_of_care` DISABLE KEYS */;
/*!40000 ALTER TABLE `type_of_care` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-19 20:33:37

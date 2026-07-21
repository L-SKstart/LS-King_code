/*
 Navicat Premium Data Transfer

 Source Server         : 192.168.1.76
 Source Server Type    : MySQL
 Source Server Version : 50728
 Source Host           : 192.168.1.76:3306
 Source Schema         : mtms_gd_pbew

 Target Server Type    : MySQL
 Target Server Version : 50728
 File Encoding         : 65001

 Date: 20/07/2026 15:20:35
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for dm_exchange_tieline_actual
-- ----------------------------
DROP TABLE IF EXISTS `dm_exchange_tieline_actual`;
CREATE TABLE `dm_exchange_tieline_actual`  (
  `id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '主键',
  `device_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '交流联络线id',
  `device_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '交流联络线名称',
  `date` datetime(0) NULL DEFAULT NULL COMMENT '数据日期',
  `curve` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL COMMENT '曲线数据',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `device_id`(`device_id`, `date`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '交流联络线实际值' ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;

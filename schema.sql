CREATE DATABASE IF NOT EXISTS checkserialnum_db

USE checkserialnum_db;

-- REGION
CREATE TABLE IF NOT EXISTS `REGION` (
    `region_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `region_name` VARCHAR(100) NOT NULL UNIQUE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- USER
CREATE TABLE IF NOT EXISTS `USER` (
    `user_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `full_name` VARCHAR(150) NOT NULL,
    `national_id` CHAR(64) NOT NULL UNIQUE,           -- HMAC-SHA256 of the National ID / Iqama
    `mobile_number` VARCHAR(20) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `preferred_language` ENUM('Arabic', 'English') DEFAULT 'English',
    `role` ENUM('registered_user', 'shop_owner', 'case_officer', 'admin') NOT NULL DEFAULT 'registered_user',
    `cr_document_path` VARCHAR(255) NULL,             -- shop owners: Commercial Registration file in storage/cr/
    `status` ENUM('active', 'suspended', 'locked') DEFAULT 'active',
    `failed_login_attempts` TINYINT UNSIGNED DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_user_mobile` (`mobile_number`),
    INDEX `idx_user_role` (`role`)
);

-- DEVICE
CREATE TABLE IF NOT EXISTS `DEVICE` (
    `device_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT UNSIGNED NOT NULL,
    `device_type` VARCHAR(50) NOT NULL,
    `brand` VARCHAR(80) NOT NULL,
    `model` VARCHAR(100) NOT NULL,
    `serial_number` VARCHAR(100) NOT NULL UNIQUE,
    `proof_of_ownership_path` VARCHAR(255) NULL,
    `status` ENUM('clear', 'stolen', 'flagged') NOT NULL DEFAULT 'clear',
    `registered_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT `fk_device_user` FOREIGN KEY (`user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX `idx_device_serial` (`serial_number`),
    INDEX `idx_device_status` (`status`)
);

-- THEFT_REPORT
CREATE TABLE IF NOT EXISTS `THEFT_REPORT` (
    `report_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `report_code` VARCHAR(20) NOT NULL UNIQUE,
    `device_id` INT UNSIGNED NOT NULL,
    `reporter_user_id` INT UNSIGNED NOT NULL,
    `case_officer_id` INT UNSIGNED NULL,
    `region_id` INT UNSIGNED NOT NULL,
    `theft_date` DATE NOT NULL,
    `additional_details` TEXT NULL,
    `case_status` ENUM(
        'Under Investigation',
        'Assigned',
        'Awaiting Evidence',
        'Recovered',
        'Flagged - Closed'
    ) NOT NULL DEFAULT 'Under Investigation',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT `fk_report_device` FOREIGN KEY (`device_id`)
        REFERENCES `DEVICE` (`device_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_report_reporter` FOREIGN KEY (`reporter_user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_report_officer` FOREIGN KEY (`case_officer_id`)
        REFERENCES `USER` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_report_region` FOREIGN KEY (`region_id`)
        REFERENCES `REGION` (`region_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX `idx_report_status` (`case_status`),
    INDEX `idx_report_date` (`theft_date`)
);

-- SERIAL_CHECK_LOG
CREATE TABLE IF NOT EXISTS `SERIAL_CHECK_LOG` (
    `log_id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `serial_entered` VARCHAR(100) NOT NULL,
    `matched_device_id` INT UNSIGNED NULL,
    `user_id` INT UNSIGNED NULL,
    `result_returned` ENUM('clear', 'stolen', 'flagged', 'not_found') NOT NULL,
    `ip_address` VARCHAR(45) NOT NULL,
    `user_agent` VARCHAR(255) NULL,
    `checked_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_log_device` FOREIGN KEY (`matched_device_id`)
        REFERENCES `DEVICE` (`device_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_log_user` FOREIGN KEY (`user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_log_serial` (`serial_entered`),
    INDEX `idx_log_ip_time` (`ip_address`, `checked_at`)
);

-- PURCHASE_VERIFICATION
CREATE TABLE IF NOT EXISTS `PURCHASE_VERIFICATION` (
    `verification_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `device_id` INT UNSIGNED NOT NULL,
    `seller_user_id` INT UNSIGNED NOT NULL,
    `buyer_user_id` INT UNSIGNED NOT NULL,
    `verification_code` VARCHAR(64) NOT NULL UNIQUE,
    `verification_status` ENUM('pending', 'approved', 'rejected', 'cancelled') NOT NULL DEFAULT 'pending',
    `initiated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT `fk_pv_device` FOREIGN KEY (`device_id`)
        REFERENCES `DEVICE` (`device_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_pv_seller` FOREIGN KEY (`seller_user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_pv_buyer` FOREIGN KEY (`buyer_user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `chk_seller_buyer_distinct` CHECK (`seller_user_id` <> `buyer_user_id`),
    INDEX `idx_pv_status` (`verification_status`)
);

-- STAFF_INVITE
CREATE TABLE IF NOT EXISTS `STAFF_INVITE` (
    `invite_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `token_hash` CHAR(64) NOT NULL UNIQUE,
    `role` ENUM('case_officer', 'admin') NOT NULL,
    `label` VARCHAR(150) NULL,
    `created_by` INT UNSIGNED NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `used_at` DATETIME NULL,
    `used_by` INT UNSIGNED NULL,
    `revoked_at` DATETIME NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_invite_creator` FOREIGN KEY (`created_by`)
        REFERENCES `USER` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_invite_user` FOREIGN KEY (`used_by`)
        REFERENCES `USER` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_invite_open` (`used_at`, `revoked_at`, `expires_at`)
);

-- PASSWORD_RESET
CREATE TABLE IF NOT EXISTS `PASSWORD_RESET` (
    `reset_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `token_hash` CHAR(64) NOT NULL UNIQUE,
    `user_id` INT UNSIGNED NOT NULL,
    `created_by` INT UNSIGNED NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `used_at` DATETIME NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_reset_user` FOREIGN KEY (`user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_reset_creator` FOREIGN KEY (`created_by`)
        REFERENCES `USER` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX `idx_reset_user_open` (`user_id`, `used_at`, `expires_at`)
);

-- CASE_ACTIVITY_LOG
CREATE TABLE IF NOT EXISTS `CASE_ACTIVITY_LOG` (
    `activity_id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT UNSIGNED NULL,
    `device_id` INT UNSIGNED NOT NULL,
    `actor_user_id` INT UNSIGNED NULL,
    `action` ENUM('report_filed', 'case_assigned', 'case_status', 'device_status') NOT NULL,
    `old_value` VARCHAR(150) NULL,
    `new_value` VARCHAR(150) NULL,
    `ip_address` VARCHAR(45) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_activity_report` FOREIGN KEY (`report_id`)
        REFERENCES `THEFT_REPORT` (`report_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_activity_device` FOREIGN KEY (`device_id`)
        REFERENCES `DEVICE` (`device_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_activity_actor` FOREIGN KEY (`actor_user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_activity_report` (`report_id`, `created_at`),
    INDEX `idx_activity_time` (`created_at`)
);

-- ADMIN_ACTIVITY_LOG
CREATE TABLE IF NOT EXISTS `ADMIN_ACTIVITY_LOG` (
    `activity_id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `actor_user_id` INT UNSIGNED NULL,
    `target_user_id` INT UNSIGNED NULL,
    `action` ENUM('user_role', 'user_status', 'user_created', 'invite_created', 'invite_revoked',
                  'invite_used', 'reset_link_created', 'password_reset') NOT NULL,
    `old_value` VARCHAR(150) NULL,
    `new_value` VARCHAR(150) NULL,
    `ip_address` VARCHAR(45) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_admin_activity_actor` FOREIGN KEY (`actor_user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_admin_activity_target` FOREIGN KEY (`target_user_id`)
        REFERENCES `USER` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_admin_activity_time` (`created_at`),
    INDEX `idx_admin_activity_target` (`target_user_id`, `created_at`)
);

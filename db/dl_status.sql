CREATE TABLE dl_status (
	video_id VARCHAR(30) NOT NULL,
	progress FLOAT NOT NULL,
	title VARCHAR(100) NOT NULL,
	created_at DATETIME,
	updated_at DATETIME,
	PRIMARY KEY (video_id)
);

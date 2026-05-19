-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('SO', 'supervisor')),
    phone TEXT,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Checkpoints table
CREATE TABLE checkpoints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius INTEGER DEFAULT 20,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Checklist items table
CREATE TABLE checklist_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    checkpoint_id UUID REFERENCES checkpoints(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    is_required BOOLEAN DEFAULT TRUE,
    order_index INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Patrol logs table
CREATE TABLE patrol_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supervisor_id UUID REFERENCES users(id),
    supervisor_name TEXT NOT NULL,
    checkpoint_id UUID REFERENCES checkpoints(id),
    checkpoint_name TEXT NOT NULL,
    shift_name TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    photo_url TEXT,
    voice_url TEXT,
    notes TEXT,
    checklist_results JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Supervisor locations table (for real-time tracking)
CREATE TABLE supervisor_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supervisor_id UUID REFERENCES users(id) UNIQUE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    last_update TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- App Settings table
CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    min_interval_minutes INTEGER DEFAULT 30,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT one_row CHECK (id = 1)
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT, -- e.g., 'patrol_update', 'alert'
    related_id UUID, -- ID of the patrol log for redirection
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger to automatically create notification on new patrol log
CREATE OR REPLACE FUNCTION notify_so_on_patrol()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notifications (title, message, type, related_id)
    VALUES (
        'Patrol Update from ' || NEW.supervisor_name,
        'Completed patrol at ' || NEW.checkpoint_name || ' during ' || COALESCE(NEW.shift_name, 'shift'),
        'patrol_update',
        NEW.id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_patrol_notification ON patrol_logs;
CREATE TRIGGER tr_patrol_notification
AFTER INSERT ON patrol_logs
FOR EACH ROW
EXECUTE FUNCTION notify_so_on_patrol();

-- Insert default settings
INSERT INTO app_settings (id, min_interval_minutes) VALUES (1, 30) ON CONFLICT (id) DO NOTHING;

-- Indexes
CREATE INDEX idx_patrol_logs_supervisor ON patrol_logs(supervisor_id);
CREATE INDEX idx_patrol_logs_timestamp ON patrol_logs(timestamp);
CREATE INDEX idx_checklist_items_checkpoint ON checklist_items(checkpoint_id);
CREATE INDEX idx_supervisor_locations_update ON supervisor_locations(last_update);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Enable real-time
ALTER PUBLICATION supabase_realtime ADD TABLE supervisor_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE app_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE patrol_logs;

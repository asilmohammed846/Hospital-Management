-- ============================================================
-- CODE FORGEX — INTEGRATED HOSPITAL MANAGEMENT SYSTEM
-- Complete Supabase Schema with Full Foreign Key Integrity
-- ============================================================

-- 1. PROFILES TABLE (extends Supabase auth.users)
-- Roles: 'admin' (Receptionist), 'doctor', 'pharmacy'
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'doctor', 'pharmacy')),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. DOCTORS TABLE (extended profile for doctors)
CREATE TABLE IF NOT EXISTS doctors (
  id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  specialization TEXT NOT NULL DEFAULT 'General Medicine',
  consultation_fee NUMERIC(10,2) NOT NULL DEFAULT 500,
  is_available BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. PATIENTS TABLE (registered by reception)
CREATE TABLE IF NOT EXISTS patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unique_pid TEXT UNIQUE NOT NULL,          -- e.g. PID-20260410-0001
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age > 0 AND age <= 150),
  gender TEXT NOT NULL CHECK (gender IN ('Male', 'Female', 'Other')),
  phone TEXT,
  address TEXT,
  blood_group TEXT,
  patient_type TEXT NOT NULL DEFAULT 'OPD' CHECK (patient_type IN ('OPD', 'IPD')),
  admission_date DATE,
  discharge_date DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. APPOINTMENTS TABLE
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  appointment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  queue_number INTEGER NOT NULL,
  token_status TEXT NOT NULL DEFAULT 'Waiting' CHECK (token_status IN ('Waiting', 'With Doctor', 'Completed')),
  status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Completed')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. CONSULTATIONS TABLE (filled by doctor during visit)
CREATE TABLE IF NOT EXISTS consultations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  diagnosis TEXT NOT NULL,
  medicines JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- medicines format: [{"name": "Paracetamol", "dosage": "500mg", "duration": "5 days", "frequency": "Twice daily"}]
  precautions TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. PHARMACY QUEUE TABLE (auto-populated when doctor saves consultation)
CREATE TABLE IF NOT EXISTS pharmacy_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id UUID NOT NULL REFERENCES consultations(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  medicines JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Dispensed')),
  pharmacy_cost NUMERIC(10,2) DEFAULT 0,
  dispensed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. BILLING TABLE (aggregated invoice per appointment)
CREATE TABLE IF NOT EXISTS billing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  doctor_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
  pharmacy_cost NUMERIC(10,2) NOT NULL DEFAULT 0,
  facility_charge NUMERIC(10,2) NOT NULL DEFAULT 200,
  total NUMERIC(10,2) GENERATED ALWAYS AS (doctor_fee + pharmacy_cost + facility_charge) STORED,
  payment_status TEXT NOT NULL DEFAULT 'Pending' CHECK (payment_status IN ('Pending', 'Paid')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_patient ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_patients_pid ON patients(unique_pid);
CREATE INDEX IF NOT EXISTS idx_pharmacy_queue_status ON pharmacy_queue(status);
CREATE INDEX IF NOT EXISTS idx_billing_patient ON billing(patient_id);
CREATE INDEX IF NOT EXISTS idx_billing_status ON billing(payment_status);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) Policies
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read all data (internal hospital system)
DROP POLICY IF EXISTS "Authenticated users can read profiles" ON profiles;
CREATE POLICY "Authenticated users can read profiles" ON profiles FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can read doctors" ON doctors;
CREATE POLICY "Authenticated users can read doctors" ON doctors FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can read patients" ON patients;
CREATE POLICY "Authenticated users can read patients" ON patients FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can read appointments" ON appointments;
CREATE POLICY "Authenticated users can read appointments" ON appointments FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can read consultations" ON consultations;
CREATE POLICY "Authenticated users can read consultations" ON consultations FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can read pharmacy_queue" ON pharmacy_queue;
CREATE POLICY "Authenticated users can read pharmacy_queue" ON pharmacy_queue FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can read billing" ON billing;
CREATE POLICY "Authenticated users can read billing" ON billing FOR SELECT USING (auth.role() = 'authenticated');

-- Allow insert/update for authenticated users (fine-grained control via application logic)
DROP POLICY IF EXISTS "Authenticated users can insert patients" ON patients;
CREATE POLICY "Authenticated users can insert patients" ON patients FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can update patients" ON patients;
CREATE POLICY "Authenticated users can update patients" ON patients FOR UPDATE USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can insert appointments" ON appointments;
CREATE POLICY "Authenticated users can insert appointments" ON appointments FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can update appointments" ON appointments;
CREATE POLICY "Authenticated users can update appointments" ON appointments FOR UPDATE USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can insert consultations" ON consultations;
CREATE POLICY "Authenticated users can insert consultations" ON consultations FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can insert pharmacy_queue" ON pharmacy_queue;
CREATE POLICY "Authenticated users can insert pharmacy_queue" ON pharmacy_queue FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can update pharmacy_queue" ON pharmacy_queue;
CREATE POLICY "Authenticated users can update pharmacy_queue" ON pharmacy_queue FOR UPDATE USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can insert billing" ON billing;
CREATE POLICY "Authenticated users can insert billing" ON billing FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can update billing" ON billing;
CREATE POLICY "Authenticated users can update billing" ON billing FOR UPDATE USING (auth.role() = 'authenticated');

-- Profiles: users can update own profile
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "Service role can insert profiles" ON profiles;
CREATE POLICY "Service role can insert profiles" ON profiles FOR INSERT WITH CHECK (true);

-- Enable realtime for pharmacy_queue, appointments, and billing
-- (Safe to re-run: skips tables already in the publication)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE pharmacy_queue;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE appointments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE billing;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 8. PHARMACY STOCK TABLE (inventory management)
-- ============================================================
CREATE TABLE IF NOT EXISTS pharmacy_stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_name TEXT UNIQUE NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  category TEXT NOT NULL DEFAULT 'General',
  reorder_level INTEGER NOT NULL DEFAULT 10,
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pharmacy_stock_name ON pharmacy_stock(medicine_name);

ALTER TABLE pharmacy_stock ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read pharmacy_stock" ON pharmacy_stock;
CREATE POLICY "Authenticated users can read pharmacy_stock" ON pharmacy_stock FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can insert pharmacy_stock" ON pharmacy_stock;
CREATE POLICY "Authenticated users can insert pharmacy_stock" ON pharmacy_stock FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can update pharmacy_stock" ON pharmacy_stock;
CREATE POLICY "Authenticated users can update pharmacy_stock" ON pharmacy_stock FOR UPDATE USING (auth.role() = 'authenticated');

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE pharmacy_stock;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- SEED: Common Medicines for Pharmacy Stock
-- ============================================================
INSERT INTO pharmacy_stock (medicine_name, quantity, unit_price, category, reorder_level)
VALUES
  ('Paracetamol 500mg', 200, 5, 'Antipyretic', 50),
  ('Amoxicillin 250mg', 150, 12, 'Antibiotic', 30),
  ('Ibuprofen 400mg', 180, 8, 'Analgesic', 40),
  ('Cetirizine 10mg', 120, 6, 'Antihistamine', 25),
  ('Omeprazole 20mg', 100, 10, 'Antacid', 20),
  ('Metformin 500mg', 90, 15, 'Antidiabetic', 20),
  ('Azithromycin 500mg', 80, 25, 'Antibiotic', 15),
  ('Pantoprazole 40mg', 110, 18, 'Antacid', 20),
  ('Cough Syrup 100ml', 60, 45, 'Respiratory', 15),
  ('Vitamin D3 1000IU', 200, 8, 'Supplement', 40)
ON CONFLICT (medicine_name) DO NOTHING;


-- 1. Habilitar extensión para IDs únicos (UUID)
create extension if not exists "uuid-ossp";

-- 2. Tabla de Cuentas (Accounts)
create table accounts (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users not null,
    name text not null,
    last_four text,
    currency text default 'USD',
    type text not null,
    current_balance numeric default 0,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Tabla de Categorías (Categories)
create table categories (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users not null,
    name text not null,
    icon text,
    color text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Tabla de Transacciones (Transactions)
create table transactions (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users not null,
    source_account_id uuid references accounts(id),
    dest_account_id uuid references accounts(id),
    category_id uuid references categories(id),
    amount numeric not null,
    type text not null,
    description text,
    date timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Habilitar Row Level Security (RLS) - ¡El núcleo de nuestra privacidad!
alter table accounts enable row level security;
alter table categories enable row level security;
alter table transactions enable row level security;

-- 6. Políticas de Seguridad (Solo el dueño puede ver/modificar sus propios datos)
create policy "Users can manage their own accounts"
on accounts for all using (auth.uid() = user_id);

create policy "Users can manage their own categories"
on categories for all using (auth.uid() = user_id);

create policy "Users can manage their own transactions"
on transactions for all using (auth.uid() = user_id);

-- ==========================================
-- 7. FASE 3: Ciclo de Facturación, Débito Dual y Alias
-- ==========================================

-- 7.1 Campos para Ciclo de Facturación e Identificador Dual en Cuentas
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS cutoff_day INTEGER;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS payment_day INTEGER;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS last_four_debit TEXT;

-- 7.2 Directorio de Cuentas Frecuentes (Alias para Transferencias)
CREATE TABLE IF NOT EXISTS account_aliases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users NOT NULL,
    account_number_or_last4 TEXT NOT NULL,
    contact_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS en account_aliases
ALTER TABLE account_aliases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own aliases"
ON account_aliases FOR ALL USING (auth.uid() = user_id);


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

CREATE TYPE processing_status_enum AS ENUM ('pending_payment', 'supplying', 'shipped', 'delivered', 'unknown');
CREATE TYPE processing_priority_enum AS ENUM ('low', 'medium', 'high', 'urgent', 'critical');
CREATE TYPE payment_method_enum AS ENUM ('credit_card', 'debit_card', 'cash', 'wallet', 'bnpl');
CREATE TYPE delivery_type_enum AS ENUM ('normal', 'custom', 'same_day');
CREATE TYPE shipping_method_enum AS ENUM ('ground', 'air_post', 'air_cargo');
CREATE TYPE package_size_enum AS ENUM ('small', 'medium', 'large');
CREATE TYPE envelope_type_enum AS ENUM ('normal', 'bubble');
CREATE TYPE order_product_status_enum AS ENUM ('pending', 'delivered', 'pending_return', 'return_approved', 'return_rejected');
CREATE TYPE wallet_transaction_type_enum AS ENUM ('deposit', 'payment');
CREATE TYPE tier_level_enum AS ENUM ('bronze', 'silver', 'gold');
CREATE TYPE payment_status_enum AS ENUM ('pending', 'completed', 'failed');
CREATE TYPE customer_type_enum AS ENUM ('corporate', 'consumer');

CREATE TABLE Manager (
    manager_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE Branch (
    branch_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    total_sales NUMERIC(15,2) DEFAULT 0,
    manager_id INT NOT NULL REFERENCES Manager(manager_id)
);

CREATE TABLE Customer (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT,
    gender VARCHAR(10),
    phone VARCHAR(20),
    email VARCHAR(100),
    income_level VARCHAR(50),
    relationship_status VARCHAR(20),
    vat_exemption_percent NUMERIC(5,2) DEFAULT 0,
    customer_type customer_type_enum NOT NULL
);

CREATE TABLE Corporate (
    customer_id INT PRIMARY KEY REFERENCES Customer(customer_id),
    company_name VARCHAR(200) NOT NULL,
    economic_code VARCHAR(50)
);

CREATE TABLE Consumer (
    customer_id INT PRIMARY KEY REFERENCES Customer(customer_id),
    national_id VARCHAR(20)
);

CREATE TABLE Product (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100),
    sub_category VARCHAR(100),
    discount NUMERIC(5,2) DEFAULT 0,
    cost_price NUMERIC(12,2) NOT NULL,
    sale_price NUMERIC(12,2) NOT NULL,
    vat_exemption_percent NUMERIC(5,2) DEFAULT 0,
    attributes JSONB
);

CREATE TABLE Supplier (
    supplier_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(20),
    address TEXT
);

CREATE TABLE BranchOffersProduct (
    branch_id INT REFERENCES Branch(branch_id),
    product_id INT REFERENCES Product(product_id),
    discount NUMERIC(5,2) DEFAULT 0,
    cost_price NUMERIC(12,2),
    sale_price NUMERIC(12,2),
    PRIMARY KEY (branch_id, product_id)
);

CREATE TABLE BranchProductSupplier (
    branch_id INT,
    product_id INT,
    supplier_id INT REFERENCES Supplier(supplier_id),
    supply_price NUMERIC(12,2),
    lead_time_days INT,
    PRIMARY KEY (branch_id, product_id, supplier_id),
    FOREIGN KEY (branch_id, product_id) REFERENCES BranchOffersProduct(branch_id, product_id)
);

CREATE TABLE Tier (
    level tier_level_enum PRIMARY KEY,
    min_score INT NOT NULL,
    max_score INT,
    order_discount NUMERIC(5,2) DEFAULT 0
);

INSERT INTO Tier (level, min_score, max_score, order_discount) VALUES
('bronze', 0, 999, 0),
('silver', 1000, 2000, 5),
('gold', 2001, NULL, 10);

CREATE TABLE LoyaltyAccount (
    loyalty_account_id SERIAL PRIMARY KEY,
    customer_id INT UNIQUE NOT NULL REFERENCES Customer(customer_id),
    tier_level tier_level_enum REFERENCES Tier(level) DEFAULT 'bronze'
);

CREATE TABLE Wallet (
    wallet_id SERIAL PRIMARY KEY,
    customer_id INT UNIQUE NOT NULL REFERENCES Customer(customer_id),
    balance NUMERIC(12,2) DEFAULT 0
);

CREATE TABLE Shipment (
    shipment_id SERIAL PRIMARY KEY,
    shipping_cost NUMERIC(10,2),
    shipping_date DATE,
    postal_code VARCHAR(20),
    delivery_type delivery_type_enum DEFAULT 'normal',
    shipping_method shipping_method_enum,
    recipient_address TEXT,
    city VARCHAR(100),
    region VARCHAR(100)
);

CREATE TABLE Package (
    package_id SERIAL PRIMARY KEY,
    size package_size_enum
);

CREATE TABLE Box (
    package_id INT PRIMARY KEY REFERENCES Package(package_id)
);

CREATE TABLE Envelope (
    package_id INT PRIMARY KEY REFERENCES Package(package_id),
    type envelope_type_enum
);

CREATE TABLE ShipmentPackage (
    shipment_id INT REFERENCES Shipment(shipment_id),
    package_id INT REFERENCES Package(package_id),
    PRIMARY KEY (shipment_id, package_id),
    UNIQUE (package_id)
);

CREATE TABLE "Order" (
    order_id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL,
    processing_status processing_status_enum DEFAULT 'unknown',
    processing_priority processing_priority_enum DEFAULT 'low',
    loyalty_discount NUMERIC(5,2) DEFAULT 0,
    customer_id INT NOT NULL REFERENCES Customer(customer_id),
    processed_by_branch_id INT REFERENCES Branch(branch_id),
    shipment_id INT UNIQUE REFERENCES Shipment(shipment_id)
);

CREATE TABLE OrderProduct (
    order_id INT REFERENCES "Order"(order_id),
    product_id INT REFERENCES Product(product_id),
    quantity INT NOT NULL DEFAULT 1,
    final_price_at_order NUMERIC(12,2) NOT NULL,
    payment_method payment_method_enum,
    status order_product_status_enum DEFAULT 'pending',
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE Payment (
    payment_id SERIAL PRIMARY KEY,
    status payment_status_enum DEFAULT 'pending',
    method payment_method_enum,
    order_id INT NOT NULL REFERENCES "Order"(order_id)
);

CREATE TABLE RepaymentHistory (
    repayment_id SERIAL PRIMARY KEY,
    payment_id INT NOT NULL REFERENCES Payment(payment_id),
    date DATE NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    payment_method payment_method_enum
);

CREATE TABLE WalletTransaction (
    wallet_id INT REFERENCES Wallet(wallet_id),
    transaction_id SERIAL,
    amount NUMERIC(12,2) NOT NULL,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    type wallet_transaction_type_enum NOT NULL,
    order_id INT REFERENCES "Order"(order_id),
    PRIMARY KEY (wallet_id, transaction_id)
);

CREATE TABLE PointsEarned (
    points_earned_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL UNIQUE REFERENCES "Order"(order_id),
    loyalty_account_id INT NOT NULL REFERENCES LoyaltyAccount(loyalty_account_id),
    points INT NOT NULL,
    earned_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE Feedback (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    feedback_id SERIAL,
    feedback_score INT CHECK (feedback_score >= 1 AND feedback_score <= 5),
    feedback_text TEXT,
    publish_consent BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (order_id, product_id, feedback_id),
    FOREIGN KEY (order_id, product_id) REFERENCES OrderProduct(order_id, product_id)
);

CREATE TABLE FeedbackImage (
    image_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    feedback_id INT NOT NULL,
    image_uri TEXT NOT NULL,
    FOREIGN KEY (order_id, product_id, feedback_id) REFERENCES Feedback(order_id, product_id, feedback_id)
);

CREATE TABLE ReturnRequest (
    return_request_id SERIAL PRIMARY KEY,
    request_date DATE NOT NULL,
    return_reason TEXT,
    inspection_result TEXT,
    decision_date DATE,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    FOREIGN KEY (order_id, product_id) REFERENCES OrderProduct(order_id, product_id)
);

#!/bin/bash

# Laravel + Next.js E-commerce Setup Script
# This script installs dependencies and sets up a basic e-commerce application
# with Laravel backend (PostgreSQL) and Next.js frontend

# Install required dependencies
sudo apt update && sudo apt upgrade -y

sudo apt install -y ufw

sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 8000/tcp
sudo ufw allow 3000/tcp
sudo ufw --force enable
sudo ufw reload

apt install -y php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php-pear  \
php8.3-bcmath php8.3-fpm unzip git curl php8.3-pgsql nodejs npm composer

sudo systemctl start php8.3-fpm.service
sudo systemctl enable php8.3-fpm.service

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo apt update

sudo apt install -y postgresql-16 postgresql-contrib

sudo systemctl start postgresql 
sudo systemctl enable postgresql

# Setup PostgreSQL database
sudo -su postgres psql -c "CREATE USER ecom_user WITH PASSWORD 'abc1234@';"
sudo -su postgres psql -c "CREATE DATABASE ecommerce_db;"
sudo -su postgres psql -c "ALTER DATABASE ecommerce_db OWNER TO ecom_user;"
sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ecommerce_db TO ecom_user;"

sudo apt install -y nginx-full
sudo systemctl start nginx.service
sudo systemctl enable nginx.service


########################################################################################################################################
# Install Laravel backend
########################################################################################################################################
  echo "Setting up Laravel backend..."
  composer create-project laravel/laravel ecommerce-backend
  cd ecommerce-backend

  # Install dependencies
  composer require laravel/sanctum fruitcake/laravel-cors

  # Configure .env
  cp .env.example .env
  sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/g" .env
  sed -i "s/# DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/g" .env
  sed -i "s/# DB_PORT=3306/DB_PORT=5432/g" .env
  sed -i "s/# DB_DATABASE=laravel/DB_DATABASE=ecommerce_db/g" .env
  sed -i "s/# DB_USERNAME=root/DB_USERNAME=ecom_user/g" .env
  sed -i "s/# DB_PASSWORD=/DB_PASSWORD=abc1234@/g" .env

  # Generate app key
  php artisan key:generate

  # Create models and migrations
  php artisan make:model Product -m
  php artisan make:model Category -m
  php artisan make:model Order -m
  php artisan make:model OrderItem -m

  # Update migrations
  cat > database/migrations/*_create_products_table.php << 'EOL'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description');
            $table->decimal('price', 10, 2);
            $table->integer('stock');
            $table->foreignId('category_id')->constrained();
            $table->string('image')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('products');
    }
};
EOL

  # Similar simplified migrations for other tables would go here...

  # Run migrations
  php artisan migrate

  # Create controllers
  php artisan make:controller ProductController --api
  php artisan make:controller CategoryController --api
  php artisan make:controller OrderController --api

  # Sample ProductController
  cat > app/Http/Controllers/ProductController.php << 'EOL'
<?php

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index()
    {
        return Product::with('category')->get();
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'price' => 'required|numeric',
            'stock' => 'required|integer',
            'category_id' => 'required|exists:categories,id',
            'image' => 'nullable|string'
        ]);

        return Product::create($validated);
    }

    public function show(Product $product)
    {
        return $product->load('category');
    }

    public function update(Request $request, Product $product)
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'sometimes|string',
            'price' => 'sometimes|numeric',
            'stock' => 'sometimes|integer',
            'category_id' => 'sometimes|exists:categories,id',
            'image' => 'nullable|string'
        ]);

        $product->update($validated);
        return $product;
    }

    public function destroy(Product $product)
    {
        $product->delete();
        return response()->noContent();
    }
}
EOL

  # Configure API routes
  cat > routes/api.php << 'EOL'
<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\OrderController;

Route::apiResource('products', ProductController::class);
Route::apiResource('categories', CategoryController::class);
Route::apiResource('orders', OrderController::class);
EOL

  # Configure CORS
  sed -i "/protected \$middleware = \[/a \ \ \ \ \Fruitcake\\Cors\\HandleCors::class," app/Http/Kernel.php

  # Create storage link
  php artisan storage:link

  cd ..

###################################################################################################################
# End of backend 
###################################################################################################################

###################################################################################################################
# Start frontend
###################################################################################################################

# Install Next.js frontend
  echo "Setting up Next.js frontend..."
  npx create-next-app@latest ecommerce-frontend
  cd ecommerce-frontend

  # Install dependencies
  npm install axios @chakra-ui/react @emotion/react @emotion/styled framer-motion react-icons

  # Create API client
  mkdir -p lib
  cat > lib/api.js << 'EOL'
import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:8000/api',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

export default api;
EOL

  # Create products page
  mkdir -p pages/products
  cat > pages/products/index.js << 'EOL'
import { useEffect, useState } from 'react';
import api from '../../lib/api';
import { Box, Grid, Heading, Text, Image, Button } from '@chakra-ui/react';

export default function Products() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        const response = await api.get('/products');
        setProducts(response.data);
        setLoading(false);
      } catch (error) {
        console.error('Error fetching products:', error);
        setLoading(false);
      }
    };

    fetchProducts();
  }, []);

  if (loading) return <Text>Loading...</Text>;

  return (
    <Box p={8}>
      <Heading mb={8}>Our Products</Heading>
      <Grid templateColumns="repeat(auto-fill, minmax(300px, 1fr))" gap={6}>
        {products.map((product) => (
          <Box key={product.id} borderWidth="1px" borderRadius="lg" p={4}>
            <Image src={product.image || '/placeholder-product.jpg'} alt={product.name} />
            <Heading size="md" mt={2}>{product.name}</Heading>
            <Text mt={2}>${product.price.toFixed(2)}</Text>
            <Button mt={4} colorScheme="blue">Add to Cart</Button>
          </Box>
        ))}
      </Grid>
    </Box>
  );
}
EOL

  cd ..
########################################################################################################################
# Frontend End
########################################################################################################################

  echo ""
  echo "Setup completed successfully!"
  echo ""
  echo "To start the backend:"
  echo "  cd ecommerce-backend && php artisan serve"
  echo ""
  echo "To start the frontend:"
  echo "  cd ecommerce-frontend && npm run dev"
  echo ""
  echo "Backend will run on http://localhost:8000"
  echo "Frontend will run on http://localhost:3000"



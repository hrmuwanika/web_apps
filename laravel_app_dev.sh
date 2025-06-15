#!/bin/bash

# ##### Laravel app development #####
# Laravel installer v5.14.0
# Composer v2.8.9
# Php v8.2 or higher
# Postgresql v16
# Nodejs v18 or higher
# PNPM - for dependency management
# with Laravel backend (PostgreSQL) and Next.js frontend

echo "======== Install required dependencies ==========="
sudo apt update && sudo apt upgrade -y

echo "================ Install node, npm, composer ===================="
sudo apt install -y ufw wget curl git unzip nodejs npm composer

echo "============== ufw firewall configuration ======================="
sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 8000/tcp
sudo ufw allow 3000/tcp
sudo ufw --force enable
sudo ufw reload

echo "================================ Install php8.3 ========================================================================="
sudo apt install -y php8.4 php8.4-common php8.4-cli php8.4-intl php8.4-zip php8.4-gd php8.4-mbstring php8.4-curl php8.4-xml php-pear  \
php8.4-bcmath php8.4-fpm php8.4-pgsql 

# Install laravel installer
/bin/bash -c "$(curl -fsSL https://php.new/install/linux/8.4)"
composer global require laravel/installer

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo apt update

echo "================== install postgresql v16 ================================="
sudo apt install -y postgresql-16 postgresql-client postgresql-contrib

sudo systemctl start postgresql 
sudo systemctl enable postgresql

# Setup PostgreSQL database
sudo -su postgres psql -c "CREATE USER dev_user WITH PASSWORD 'abc1234@';"
sudo -su postgres psql -c "CREATE DATABASE laradev_db;"
sudo -su postgres psql -c "ALTER DATABASE laradev_db OWNER TO dev_user;"
sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE laradev_db TO dev_user;"

sudo apt install -y nginx-full

sudo systemctl start nginx.service
sudo systemctl enable nginx.service

cd /var/www/html/
rm -rf *

########################################################################################################################################
# Install Laravel backend
########################################################################################################################################
  echo "================== Setting up Laravel backend ============================"
  laravel new laravel_backend
  cd laravel_backend

  # Configure .env
  cp .env.example .env
  sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/g" .env
  sed -i "s/# DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/g" .env
  sed -i "s/# DB_PORT=3306/DB_PORT=5432/g" .env
  sed -i "s/# DB_DATABASE=laravel/DB_DATABASE=laradev_db/g" .env
  sed -i "s/# DB_USERNAME=root/DB_USERNAME=dev_user/g" .env
  sed -i "s/# DB_PASSWORD=/DB_PASSWORD=abc1234@/g" .env

  # Generate app key
  php artisan key:generate

  # Install dependencies
  composer require laravel/sanctum fruitcake/laravel-cors
  
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

sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default

sudo cat <<EOF > /etc/nginx/sites-available/ecommerce.conf
server {
    listen 80;
    listen [::]:80;
    server_name $WEBSITE_NAME;
    root /var/www/html/ecommerce-backend/public;                       # Path to your Laravel public directory

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        #fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        #include fastcgi_params;
        #fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/ecommerce.conf /etc/nginx/sites-enabled/
nginx -t

sudo systemctl restart nginx.service

sudo chown -R www-data:www-data /var/www/html/ecommerce-backend
sudo chmod -R 775 /var/www/html/ecommerce-backend

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



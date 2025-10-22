#!/bin/bash

# Default values
RUN_AUTH=false
RUN_CARDS=false
RUN_checkout=false
RUN_TRANSACTION=false
INSTALL_DEPS=false
INSTALL_ONLY=false
AUTH_PORT=4000
CARDS_PORT=4050
checkout_PORT=4040
TRANSACTION_PORT=4030
OPEN_BROWSER=false

# Function to display usage information
show_usage() {
  echo "Usage: ./run-script.sh [options]"
  echo "Options:"
  echo "  -a, -auth, --auth         Run only the auth microservice"
  echo "  -c, -cards, --cards       Run only the cards microservice"
  echo "  -ch, -checkout, --checkout     Run only the checkout microservice"
  echo "  -t, -transaction, --transaction  Run only the transaction microservice"
  echo "  --all                     Run all microservices (default)"
  echo "  -i, --install             Install npm dependencies for selected services"
  echo "  --install-only            Install dependencies without running services"
  echo "  -o, --open                Open browser when services start"
  echo "  --auth-port PORT          Specify auth service port (default: 4000)"
  echo "  --cards-port PORT         Specify cards service port (default: 4050)"
  echo "  --checkout-port PORT        Specify checkout service port (default: 4040)"
  echo "  --transaction-port PORT   Specify transaction service port (default: 4030)"
  echo "  -h, --help                Show this help message"
  echo ""
  echo "If no options are provided, all microservices will be started."
  echo ""
  echo "Examples:"
  echo "  ./run-script.sh                        # Run all microservices"
  echo "  ./run-script.sh -auth                  # Run only auth service"
  echo "  ./run-script.sh -auth -cards           # Run auth and cards services"
  echo "  ./run-script.sh -auth -i               # Install deps for and run auth service"
  echo "  ./run-script.sh --all --install-only   # Install deps for all services (don't run)"
  echo "  ./run-script.sh -auth --install-only   # Install deps for auth only (don't run)"
  echo "  ./run-script.sh --all -i               # Install deps for all, then run all"
  echo "  ./run-script.sh --auth-port 5000       # Run auth on port 5000"
  echo "  ./run-script.sh --all -o               # Run all services and open browser"
  echo "  ./run-script.sh -auth -cards -i        # Install deps for auth & cards, then run them"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
  # No arguments provided, run all by default
  RUN_AUTH=true
  RUN_CARDS=true
  RUN_CHECKOUT=true
  RUN_TRANSACTION=true
else
  while [ "$1" != "" ]; do
    case $1 in
      -a | -auth | --auth )         RUN_AUTH=true
                                   ;;
      -c | -cards | --cards )       RUN_CARDS=true
                                   ;;
      -ch | -checkout | --checkout )     RUN_checkout=true
                                   ;;
      -t | -transaction | --transaction )  RUN_TRANSACTION=true
                                          ;;
      --all )                       RUN_AUTH=true
                                   RUN_CARDS=true
                                   RUN_checkout=true
                                   RUN_TRANSACTION=true
                                   ;;
      -i | --install )              INSTALL_DEPS=true
                                   ;;
      --install-only )              INSTALL_ONLY=true
                                   INSTALL_DEPS=true
                                   ;;
      -o | --open )                 OPEN_BROWSER=true
                                   ;;
      --auth-port )                 shift
                                   AUTH_PORT=$1
                                   ;;
      --cards-port )                shift
                                   CARDS_PORT=$1
                                   ;;
      --checkout-port )               shift
                                   checkout_PORT=$1
                                   ;;
      --transaction-port )          shift
                                   TRANSACTION_PORT=$1
                                   ;;
      -h | --help )                 show_usage
                                   exit
                                   ;;
      * )                           echo "Unknown option: $1"
                                   show_usage
                                   exit 1
    esac
    shift
  done
fi

# If no service is specified, run all by default
if [ "$RUN_AUTH" = false ] && [ "$RUN_CARDS" = false ] && [ "$RUN_checkout" = false ] && [ "$RUN_TRANSACTION" = false ]; then
  RUN_AUTH=true
  RUN_CARDS=true
  RUN_CHECKOUT=true
  RUN_TRANSACTION=true
fi

# Function to open browser after a delay
open_browser() {
  local port=$1
  local service_name=$2
  sleep 3  # Wait for the server to start
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "http://localhost:$port"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    xdg-open "http://localhost:$port"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    start "http://localhost:$port"
  else
    echo "Could not open browser automatically. Please open http://localhost:$port manually for $service_name."
  fi
}

# Function to check if port is available
check_port() {
  local port=$1
  if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Warning: Port $port is already in use. The service may fail to start."
    return 1
  fi
  return 0
}

# Function to install dependencies for a service
install_dependencies() {
  local service_dir=$1
  local service_name=$2

  echo "📦 Installing dependencies for $service_name..."

  if [ ! -d "$service_dir" ]; then
    echo "Error: Directory $service_dir not found"
    return 1
  fi

  if [ ! -f "$service_dir/package.json" ]; then
    echo "Error: package.json not found in $service_dir"
    return 1
  fi

  (cd "$service_dir" && npm install)

  if [ $? -eq 0 ]; then
    echo "✓ Dependencies installed successfully for $service_name"
    return 0
  else
    echo "Failed to install dependencies for $service_name"
    return 1
  fi
}

# Track background processes
AUTH_PID=""
CARDS_PID=""
CHECKOUT_PID=""
TRANSACTION_PID=""

# Cleanup function
cleanup() {
  echo ""
  echo "Shutting down microservices..."
  if [ ! -z "$AUTH_PID" ]; then
    kill $AUTH_PID 2>/dev/null
    echo "✓ Auth service stopped"
  fi
  if [ ! -z "$CARDS_PID" ]; then
    kill $CARDS_PID 2>/dev/null
    echo "✓ Cards service stopped"
  fi
  if [ ! -z "$CHECKOUT_PID" ]; then
    kill $CHECKOUT_PID 2>/dev/null
    echo "✓ Checkout service stopped"
  fi
  if [ ! -z "$TRANSACTION_PID" ]; then
    kill $TRANSACTION_PID 2>/dev/null
    echo "✓ Transaction service stopped"
  fi
  echo "All services stopped."
}

# Set up trap to cleanup on exit
trap cleanup EXIT

# Check if required directories exist
check_directories() {
  local missing_dirs=()

  if [ "$RUN_AUTH" = true ] && [ ! -d "script-auth-microservice" ]; then
    missing_dirs+=("script-auth-microservice")
  fi

  if [ "$RUN_CARDS" = true ] && [ ! -d "script-cards-microservice" ]; then
    missing_dirs+=("script-cards-microservice")
  fi

  if [ "$RUN_CHECKOUT" = true ] && [ ! -d "script-checkout-microservice" ]; then
    missing_dirs+=("script-checkout-microservice")
  fi

  if [ "$RUN_TRANSACTION" = true ] && [ ! -d "script-transaction-microservice" ]; then
    missing_dirs+=("script-transaction-microservice")
  fi

  if [ ${#missing_dirs[@]} -ne 0 ]; then
    echo "Error: The following required directories are missing:"
    for dir in "${missing_dirs[@]}"; do
      echo "  - $dir"
    done
    echo ""
    echo "Please ensure all microservice directories are present in the current directory."
    exit 1
  fi
}

# Check directories before starting
check_directories

# Install dependencies if requested
if [ "$INSTALL_DEPS" = true ]; then
  echo ""
  echo "🔧 Installing Dependencies..."
  echo "=============================="

  INSTALL_FAILED=false

  if [ "$RUN_AUTH" = true ]; then
    install_dependencies "script-auth-microservice" "Auth Service"
    [ $? -ne 0 ] && INSTALL_FAILED=true
  fi

  if [ "$RUN_CARDS" = true ]; then
    install_dependencies "script-cards-microservice" "Cards Service"
    [ $? -ne 0 ] && INSTALL_FAILED=true
  fi

  if [ "$RUN_CHECKOUT" = true ]; then
    install_dependencies "script-checkout-microservice" "Checkout Service"
    [ $? -ne 0 ] && INSTALL_FAILED=true
  fi

  if [ "$RUN_TRANSACTION" = true ]; then
    install_dependencies "script-transaction-microservice" "Transaction Service"
    [ $? -ne 0 ] && INSTALL_FAILED=true
  fi

  if [ "$INSTALL_FAILED" = true ]; then
    echo ""
    echo "Some dependencies failed to install. Please check the errors above."
    exit 1
  fi

  echo ""
  echo "✓ All dependencies installed successfully!"
  echo ""

  # Exit if install-only mode
  if [ "$INSTALL_ONLY" = true ]; then
    echo "✓ Installation complete. Exiting (--install-only mode)."
    exit 0
  fi
fi

# Check ports before starting
echo "Checking port availability..."
if [ "$RUN_AUTH" = true ]; then
  check_port $AUTH_PORT
fi
if [ "$RUN_CARDS" = true ]; then
  check_port $CARDS_PORT
fi
if [ "$RUN_CHECKOUT" = true ]; then
  check_port $CHECKOUT_PORT
fi
if [ "$RUN_TRANSACTION" = true ]; then
  check_port $TRANSACTION_PORT
fi

echo ""
echo "🚀 Starting script Microservices..."
echo "=================================="

# Start the services
if [ "$RUN_AUTH" = true ] && [ "$RUN_CARDS" = true ] && [ "$RUN_CHECKOUT" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting all microservices..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start cards service in background
  echo "Starting Cards service on port $CARDS_PORT..."
  (cd script-cards-microservice && PORT=$CARDS_PORT npm run dev) &
  CARDS_PID=$!

  # Start checkout service in background
  echo "Starting Checkout service on port $CHECKOUT_PORT..."
  (cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev) &
  checkout_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $CARDS_PORT "Cards Service" &
    open_browser $checkout_PORT "checkout Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_AUTH" = true ] && [ "$RUN_CARDS" = true ] && [ "$RUN_checkout" = true ]; then
  echo "Starting Auth, Cards, and checkout services..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start cards service in background
  echo "Starting Cards service on port $CARDS_PORT..."
  (cd script-cards-microservice && PORT=$CARDS_PORT npm run dev) &
  CARDS_PID=$!

  # Start checkout service in foreground
  echo "Starting Checkout service on port $checkout_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $CARDS_PORT "Cards Service" &
    open_browser $CHECKOUT_PORT "Checkout Service" &
  fi
  cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev

elif [ "$RUN_AUTH" = true ] && [ "$RUN_CARDS" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting Auth, Cards, and Transaction services..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start cards service in background
  echo "Starting Cards service on port $CARDS_PORT..."
  (cd script-cards-microservice && PORT=$CARDS_PORT npm run dev) &
  CARDS_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $CARDS_PORT "Cards Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_AUTH" = true ] && [ "$RUN_checkout" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting Auth, checkout, and Transaction services..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start checkout service in background
  echo "Starting Checkout service on port $checkout_PORT..."
  (cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev) &
  checkout_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $CHECKOUT_PORT "Checkout Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_CARDS" = true ] && [ "$RUN_checkout" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting Cards, Checkout, and Transaction services..."

  # Start cards service in background
  echo "Starting Cards service on port $CARDS_PORT..."
  (cd script-cards-microservice && PORT=$CARDS_PORT npm run dev) &
  CARDS_PID=$!

  # Start checkout service in background
  echo "Starting checkout service on port $checkout_PORT..."
  (cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev) &
  checkout_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $CARDS_PORT "Cards Service" &
    open_browser $CHECKOUT_PORT "Checkout Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_AUTH" = true ] && [ "$RUN_CARDS" = true ]; then
  echo "Starting Auth and Cards services..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start cards service in foreground
  echo "Starting Cards service on port $CARDS_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $CARDS_PORT "Cards Service" &
  fi
  cd script-cards-microservice && PORT=$CARDS_PORT npm run dev

elif [ "$RUN_AUTH" = true ] && [ "$RUN_CHECKOUT" = true ]; then
  echo "Starting Auth and Checkout services..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start checkout service in foreground
  echo "Starting Checkout service on port $CHECKOUT_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $CHECKOUT_PORT "Checkout Service" &
  fi
  cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev

elif [ "$RUN_AUTH" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting Auth and Transaction services..."

  # Start auth service in background
  echo "Starting Auth service on port $AUTH_PORT..."
  (cd script-auth-microservice && PORT=$AUTH_PORT npm run dev) &
  AUTH_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_CARDS" = true ] && [ "$RUN_CHECKOUT" = true ]; then
  echo "Starting Cards and Checkout services..."

  # Start cards service in background
  echo "Starting Cards service on port $CARDS_PORT..."
  (cd script-cards-microservice && PORT=$CARDS_PORT npm run dev) &
  CARDS_PID=$!

  # Start checkout service in foreground
  echo "Starting checkout service on port $checkout_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $CARDS_PORT "Cards Service" &
    open_browser $CHECKOUT_PORT "Checkout Service" &
  fi
  cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev

elif [ "$RUN_CARDS" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting Cards and Transaction services..."

  # Start cards service in background
  echo "Starting Cards service on port $CARDS_PORT..."
  (cd script-cards-microservice && PORT=$CARDS_PORT npm run dev) &
  CARDS_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $CARDS_PORT "Cards Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_checkout" = true ] && [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting checkout and Transaction services..."

  # Start checkout service in background
  echo "Starting Checkout service on port $CHECKOUT_PORT..."
  (cd script-checkout-microservice && PORT=$CHECKOUT_PORT npm run dev) &
  checkout_PID=$!

  # Start transaction service in foreground
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $checkout_PORT "checkout Service" &
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev

elif [ "$RUN_AUTH" = true ]; then
  echo "Starting Auth service on port $AUTH_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $AUTH_PORT "Auth Service" &
  fi
  cd script-auth-microservice && PORT=$AUTH_PORT npm run dev

elif [ "$RUN_CARDS" = true ]; then
  echo "Starting Cards service on port $CARDS_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $CARDS_PORT "Cards Service" &
  fi
  cd script-cards-microservice && PORT=$CARDS_PORT npm run dev

elif [ "$RUN_CHECKOUT" = true ]; then
  echo "Starting Checkout service on port $CHECKOUT_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $CHECKOUT_PORT "Checkout Service" &
  fi
  cd script-checkout-microservice && PORT=$checkout_PORT npm run dev

elif [ "$RUN_TRANSACTION" = true ]; then
  echo "Starting Transaction service on port $TRANSACTION_PORT..."
  if [ "$OPEN_BROWSER" = true ]; then
    open_browser $TRANSACTION_PORT "Transaction Service" &
  fi
  cd script-transaction-microservice && PORT=$TRANSACTION_PORT npm run dev
fi

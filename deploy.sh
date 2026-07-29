#!/bin/bash

REPO=""
AND=""
BRANCH=""
BASE_DIR="$HOME/projects"
fetch_git(){
        mkdir -p "$BASE_DIR"
        cd "$BASE_DIR" || exit 1

        echo "Enter the GitHub Repo URL to clone"
        read -r REPO

        echo "Enter the Branch"
        read -r BRANCH

        echo "Enter the PORT number"
        read -r PORT

        if [[ -z "$BRANCH" ]]; then
                BRANCH="main"
        fi

        if [[ -z "$PORT" ]]; then
                PORT=3000
        fi

        if [[ -n "$REPO" ]]; then
                if ! git ls-remote "$REPO" HEAD &>/dev/null; then
                        echo "Invalid or inaccessible repository: $REPO"
                        exit 1
                fi

                DIR=$(basename "$REPO" .git)

                if [ ! -d "$DIR" ]; then
                        echo "Cloning repository: $REPO"
                        git clone -b "$BRANCH" "$REPO" || exit 1
                        cd "$DIR"
                elif [ -d "$DIR" ]; then
                        cd "$DIR"

                        git fetch origin

                        if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
                                git checkout "$BRANCH"
                        else
                                git checkout -b "$BRANCH" "origin/$BRANCH"
                        fi
                        git pull origin "$BRANCH" || exit 1
                fi

        echo "Do you have any envitoment variable to save? ({Yes/y}/{No/n})"
        read -r ANS

        if [[ "$ANS" =~ ^[Yy]$ ]]; then
                echo "Enter environment variable (e.g., API_KEY=12345):"
                read -r ENV_VAR
        fi

        if [[ -n "$ENV_VAR" ]]; then
            if [[ -f ".env" ]]; then
                echo "Updating existing .env file..."
                echo "$ENV_VAR" >> .env
            else
                echo "Creating new .env file..."
                echo "$ENV_VAR" > .env
            fi
            echo ".env file updated/created with: $ENV_VAR"
        else
            echo "No variables entered. Skipping."
        fi
    else
        echo "Skipping .env creation/update."
    fi
}

i_build(){
        npm install && npm run build && PORT="$PORT" pm2 start npm --name "$DIR" -- start
}

fetch_git
i_build
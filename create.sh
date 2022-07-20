npm init -y # init NodeJS repo

wget https://raw.githubusercontent.com/github/gitignore/master/Node.gitignore \
-O .gitignore # create gitignore

npm install typescript --save-dev # add typescript dev dep

npm install @types/node --save-dev # add typescript node dev dep

npx tsc --init --rootDir src --outDir build \
--esModuleInterop --resolveJsonModule --lib es6 \
--module commonjs --allowJs true --noImplicitAny true # config typescript

npm install web3 && npm install solc && npm install axios

mkdir src && touch src/index.ts
# cpuex2019 yokyo

## Set up

```sh
git submodule update --init --recursive
make install

# set envs
export PATH="$PATH:/opt/riscv32/bin"
export RISCV="/opt/riscv32"
```

## Run emulator

```sh
make run
```

# pacman wrapper

# source: https://github.com/strugee/yaourt/blob/master/src/lib/util.sh.in

# explode_args ($arg1,...)
# -ab --long -> -a -b --long
# set $OPTS
explode_args() {
        unset OPTS
        local arg=$1
        while [[ $arg ]]; do
                [[ $arg = "--" ]] && OPTS+=("$@") && break;
                if [[ ${arg:0:1} = "-" && ${arg:1:1} != "-" ]]; then
                        OPTS+=("-${arg:1:1}")
                        (( ${#arg} > 2 )) && arg="-${arg:2}" || { shift; arg=$1; }
                else
                        OPTS+=("$arg"); shift; arg=$1
                fi
        done
}

# based on source: https://github.com/archlinuxfr/yaourt/blob/master/src/yaourt.sh.in

pacman() {
        CMDLINE_ARGS=("$@")

        explode_args "$@"

        SYNC_REQUESTED=0

        for ((i = 0; i < "${#OPTS[@]}"; i++)); do
                case ${OPTS[$i]} in
                        -S|--sync)          unset OPTS[$i]; SYNC_REQUESTED=1;
                esac
        done

        if [[ SYNC_REQUESTED -eq 1 ]]; then
                # Parse all other options
                set -- "${OPTS[@]}"
                unset OPTS

                REFRESH=0

                while [[ $1 ]]; do
                        case "$1" in
                                -y|--refresh)       (( REFRESH=1 ));;
                        esac
                        shift
                done
                if [[ $REFRESH -eq 1 ]]; then
			echo "starting sync"
                        /root/bin/pacman_ipfs_sync
                fi
        fi
/bin/pacman "${CMDLINE_ARGS[@]}"
}

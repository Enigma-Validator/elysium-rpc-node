# Elysium RPC node: Arbitrum Nitro with the Elysium chain config baked in.
ARG NITRO_IMAGE=offchainlabs/nitro-node:v3.9.5-66e42c4
FROM ${NITRO_IMAGE}

COPY --chown=user:user config/chainInfo.json /config/chainInfo.json
COPY --chown=user:user --chmod=755 entrypoint.sh /usr/local/bin/elysium-entrypoint

# Data lives in /home/user/.arbitrum (mounted as a volume by docker-compose).
USER user
WORKDIR /home/user

EXPOSE 8547 8546 6070

ENTRYPOINT ["/usr/local/bin/elysium-entrypoint"]

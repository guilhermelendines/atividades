-- Criação da tabela tb_cliente com alterações
CREATE TABLE tb_cliente (
    cliente_id SERIAL PRIMARY KEY,
    nome_cliente VARCHAR(200) NOT NULL
);

-- Inserindo dados na tabela tb_cliente
INSERT INTO tb_cliente (nome_cliente) VALUES ('João Silva'), ('Ana Oliveira');

-- Selecionando todos os dados da tabela tb_cliente
SELECT * FROM tb_cliente;


-- Criação da tabela tb_tipo_conta com alterações
CREATE TABLE tb_tipo_conta (
    tipo_conta_id SERIAL PRIMARY KEY,
    descricao_tipo VARCHAR(200) NOT NULL
);

-- Inserindo dados na tabela tb_tipo_conta
INSERT INTO tb_tipo_conta (descricao_tipo) VALUES ('Conta Corrente'), ('Conta Investimento');

-- Selecionando todos os dados da tabela tb_tipo_conta
SELECT * FROM tb_tipo_conta;


-- Criação da tabela tb_conta com alterações
CREATE TABLE tb_conta (
    conta_id SERIAL PRIMARY KEY,
    estado VARCHAR(200) NOT NULL DEFAULT 'ativa',
    criada_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultima_movimentacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    saldo_atual NUMERIC(10, 2) NOT NULL DEFAULT 1500 CHECK (saldo_atual >= 1500),
    cliente_id INT NOT NULL,
    tipo_conta_id INT NOT NULL,
    CONSTRAINT fk_cliente FOREIGN KEY (cliente_id) REFERENCES tb_cliente(cliente_id),
    CONSTRAINT fk_tipo_conta FOREIGN KEY (tipo_conta_id) REFERENCES tb_tipo_conta(tipo_conta_id)
);

-- Selecionando todos os dados da tabela tb_conta
SELECT * FROM tb_conta;


-- Função para abrir conta com alterações
DROP FUNCTION IF EXISTS fn_abrir_nova_conta;
CREATE OR REPLACE FUNCTION fn_abrir_nova_conta (
    IN p_cliente_id INT, 
    IN p_saldo_inicial NUMERIC(10, 2), 
    IN p_tipo_conta_id INT
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO tb_conta (cliente_id, saldo_atual, tipo_conta_id) 
    VALUES ($1, $2, $3);
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$

-- Bloco anônimo para testar a abertura de conta
DO $$
DECLARE
    v_cliente_id INT := 2;
    v_saldo_inicial NUMERIC(10, 2) := 800;
    v_tipo_conta_id INT := 2;
    v_resultado BOOLEAN;
BEGIN
    SELECT fn_abrir_nova_conta(v_cliente_id, v_saldo_inicial, v_tipo_conta_id) INTO v_resultado;
    RAISE NOTICE 'Conta com saldo de R$% foi aberta: %', v_saldo_inicial, v_resultado;

    v_saldo_inicial := 1600;
    SELECT fn_abrir_nova_conta(v_cliente_id, v_saldo_inicial, v_tipo_conta_id) INTO v_resultado;
    RAISE NOTICE 'Conta com saldo de R$% foi aberta: %', v_saldo_inicial, v_resultado;
END;
$$


-- Função para depositar com alterações
DROP FUNCTION IF EXISTS fn_depositar_valor;
CREATE OR REPLACE FUNCTION fn_depositar_valor (
    IN p_cliente_id INT, 
    IN p_conta_id INT,
    IN p_valor_deposito NUMERIC(10, 2)
) RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_novo_saldo NUMERIC(10, 2);
BEGIN
    UPDATE tb_conta SET saldo_atual = saldo_atual + p_valor_deposito 
    WHERE cliente_id = p_cliente_id AND conta_id = p_conta_id;

    SELECT saldo_atual FROM tb_conta 
    WHERE cliente_id = p_cliente_id AND conta_id = p_conta_id INTO v_novo_saldo;

    RETURN v_novo_saldo;
END;
$$

-- Bloco anônimo para testar depósito
DO $$
DECLARE
    v_cliente_id INT := 2;
    v_conta_id INT := 2;
    v_valor_deposito NUMERIC(10, 2) := 300;
    v_novo_saldo NUMERIC(10, 2);
BEGIN
    SELECT fn_depositar_valor(v_cliente_id, v_conta_id, v_valor_deposito) INTO v_novo_saldo;
    RAISE NOTICE 'Após depositar R$%, o saldo resultante é R$%', v_valor_deposito, v_novo_saldo;
END;
$$


-- Função para consultar saldo com alterações
DROP FUNCTION IF EXISTS fn_saldo_consulta;
CREATE OR REPLACE FUNCTION fn_saldo_consulta (
    IN p_cliente_id INT, 
    IN p_conta_id INT
) RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo NUMERIC(10, 2);
BEGIN
    SELECT saldo_atual FROM tb_conta 
    WHERE conta_id = p_cliente_id AND conta_id = p_conta_id INTO v_saldo;
    RETURN v_saldo;
END;
$$


-- Função para transferir com alterações
DROP FUNCTION IF EXISTS fn_realizar_transferencia;
CREATE OR REPLACE FUNCTION fn_realizar_transferencia(
    p_remetente_id_cliente INT,
    p_remetente_id_conta INT,
    p_destinatario_id_cliente INT,
    p_destinatario_id_conta INT,
    p_valor NUMERIC(10, 2)
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo_remetente NUMERIC(10, 2);
    v_saldo_destinatario NUMERIC(10, 2);
    v_estado_remetente VARCHAR(200);
    v_estado_destinatario VARCHAR(200);
BEGIN
    SELECT saldo_atual, estado INTO v_saldo_remetente, v_estado_remetente
    FROM tb_conta
    WHERE cliente_id = p_remetente_id_cliente AND conta_id = p_remetente_id_conta;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    SELECT saldo_atual, estado INTO v_saldo_destinatario, v_estado_destinatario
    FROM tb_conta
    WHERE cliente_id = p_destinatario_id_cliente AND conta_id = p_destinatario_id_conta;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_estado_remetente != 'ativa' OR v_estado_destinatario != 'ativa' THEN
        RETURN FALSE;
    END IF;

    IF v_saldo_remetente < p_valor THEN
        RETURN FALSE;
    END IF;

    UPDATE tb_conta
    SET saldo_atual = saldo_atual - p_valor,
        ultima_movimentacao = CURRENT_TIMESTAMP
    WHERE cliente_id = p_remetente_id_cliente AND conta_id = p_remetente_id_conta;

    UPDATE tb_conta
    SET saldo_atual = saldo_atual + p_valor,
        ultima_movimentacao = CURRENT_TIMESTAMP
    WHERE cliente_id = p_destinatario_id_cliente AND conta_id = p_destinatario_id_conta;

    RETURN TRUE;
END;
$$

-- Bloco anônimo para testar consulta de saldo
DO $$
DECLARE
    v_saldo NUMERIC;
BEGIN
    v_saldo := fn_saldo_consulta(1, 1);
    IF v_saldo IS NOT NULL THEN
        RAISE NOTICE 'Saldo da conta 1 do cliente 1: %', v_saldo;
    ELSE
        RAISE NOTICE 'Conta 1 do cliente 1 não encontrada.';
    END IF;
END;
$$

-- Bloco anônimo para testar transferência
DO $$
DECLARE
    v_transferencia_resultado BOOLEAN;
    r_cliente_id INT := 1;
    r_conta_id INT := 1;
    d_cliente_id INT := 2;
    d_conta_id INT := 2;
    valor_transferencia NUMERIC(10, 2) := 250;
BEGIN
    SELECT fn_realizar_transferencia(
        r_cliente_id, 
        r_conta_id, 
        d_cliente_id, 
        d_conta_id, 
        valor_transferencia
    ) INTO v_transferencia_resultado;

    IF v_transferencia_resultado THEN
        RAISE NOTICE 'Transferência realizada com sucesso!';
    ELSE
        RAISE NOTICE 'Falha na transferência.';
    END IF;
END;
$$

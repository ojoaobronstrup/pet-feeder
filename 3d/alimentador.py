"""Modelo paramétrico do alimentador. Todas as dimensões lineares estão em mm."""

import argparse
from itertools import combinations, product
from math import cos, radians, sin, sqrt
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

import cadquery as cq


MESA = (220, 220, 220)
META_KG = 3
DENSIDADE_KG_L = 0.50

TOPO_RESERVATORIO = 208
PAREDE = 4
ALTURA_RESERVATORIO = 218
FOLGA_ENCHIMENTO = 10
ALTURA_FLANGE = 8
TOPO_FUNIL = 92
ENTRADA_X = 74
ENTRADA_Y = 42
FUROS_RESERVATORIO = tuple(product((-50, 50), (-38, 38)))

EIXO_Z = 80
DECK_Z = EIXO_Z + 40
TRASEIRA_X = -74
FIM_CAMARA_X = 104
FACE_MOTOR_X = -120
ESPESSURA_PLACA = 8
FUROS_TRASEIROS = tuple(product((-36, 36), (-29, 29)))
FUROS_NEMA17 = tuple(product((-15.5, 15.5), repeat=2))

RAIO_CAMARA = 24
RAIO_ROSCA = 23
RAIO_NUCLEO = 9
PASSO = 32
INICIO_HELICE_X = -64
COMPRIMENTO_HELICE = 5 * PASSO
DIAMETRO_PONTA = 8
DIAMETRO_MANCAL = 8.6


def caixa(x0, x1, y0, y1, z0, z1):
    return cq.Solid.makeBox(x1 - x0, y1 - y0, z1 - z0, (x0, y0, z0))


def cilindro_x(diametro, x0, x1, y=0, z=EIXO_Z):
    return cq.Solid.makeCylinder(diametro / 2, x1 - x0, (x0, y, z), (1, 0, 0))


def transicao_retangular(z0, largura0, profundidade0, z1, largura1, profundidade1):
    return (
        cq.Workplane("XY", origin=(0, 0, z0))
        .rect(largura0, profundidade0)
        .workplane(offset=z1 - z0)
        .rect(largura1, profundidade1)
        .loft(ruled=True)
        .val()
    )


def reservatorio():
    interno = TOPO_RESERVATORIO - 2 * PAREDE
    meia_largura = TOPO_RESERVATORIO / 2
    flange = caixa(-58, 58, -46, 46, 0, ALTURA_FLANGE)
    funil = transicao_retangular(
        ALTURA_FLANGE, ENTRADA_X + 2 * PAREDE, ENTRADA_Y + 2 * PAREDE,
        TOPO_FUNIL, TOPO_RESERVATORIO, TOPO_RESERVATORIO,
    )
    paredes = caixa(
        -meia_largura, meia_largura, -meia_largura, meia_largura,
        TOPO_FUNIL, ALTURA_RESERVATORIO,
    )
    garganta = caixa(
        -ENTRADA_X / 2, ENTRADA_X / 2, -ENTRADA_Y / 2, ENTRADA_Y / 2,
        -1, ALTURA_FLANGE,
    )
    cavidade_funil = transicao_retangular(
        ALTURA_FLANGE, ENTRADA_X, ENTRADA_Y, TOPO_FUNIL, interno, interno
    )
    nivel = ALTURA_RESERVATORIO - FOLGA_ENCHIMENTO
    # O volume útil começa na face inferior da flange e termina 10 mm abaixo do topo.
    litros = (
        ENTRADA_X * ENTRADA_Y * ALTURA_FLANGE
        + cavidade_funil.Volume()
        + interno**2 * (nivel - TOPO_FUNIL)
    ) / 1_000_000
    cavidade = caixa(-interno / 2, interno / 2, -interno / 2, interno / 2,
                     TOPO_FUNIL, ALTURA_RESERVATORIO + 1)
    furos = [
        cq.Solid.makeCylinder(2.25, ALTURA_FLANGE + 2, (x, y, -1))
        for x, y in FUROS_RESERVATORIO
    ]
    corpo = flange.fuse(funil, paredes).cut(garganta.fuse(cavidade_funil, cavidade), *furos)
    return corpo.clean().translate((0, 0, DECK_Z)), litros


def tampa():
    encaixe = (TOPO_RESERVATORIO - 2 * PAREDE) / 2 - 0.45
    aba = TOPO_RESERVATORIO / 2 + 2
    placa = caixa(-aba, aba, -aba, aba, 0, 4)
    anel = caixa(-encaixe, encaixe, -encaixe, encaixe, -4, 0).cut(
        caixa(-encaixe + PAREDE, encaixe - PAREDE,
              -encaixe + PAREDE, encaixe - PAREDE, -5, 1)
    )
    return placa.fuse(anel).clean().translate((0, 0, DECK_Z + ALTURA_RESERVATORIO))


def camara():
    # O arco conserva a folga circular. As faces a 45° formam o teto imprimível.
    tangencia = RAIO_CAMARA / sqrt(2)
    return (
        cq.Workplane("YZ", origin=(TRASEIRA_X - 1, 0, EIXO_Z))
        .moveTo(tangencia, tangencia)
        .threePointArc((0, -RAIO_CAMARA), (-tangencia, tangencia))
        .lineTo(0, 2 * tangencia)
        .close()
        .extrude(FIM_CAMARA_X - TRASEIRA_X + 1)
        .val()
    )


def canal_descarga():
    return (
        cq.Workplane("XZ", origin=(0, 21, 0))
        # A boca inferior fica adiante da hélice e desvia a ração para a tigela.
        .polyline([(72, EIXO_Z + 5), (98, EIXO_Z + 5), (121, 32), (100, 32)])
        .close()
        .extrude(42)
        .val()
    )


def corpo():
    base = caixa(-87, 62, -92, 92, 0, 8)
    carenagem = (
        cq.Workplane("XZ", origin=(0, 50, 0))
        .polyline([(TRASEIRA_X, 8), (52, 8), (69, 34),
                   (127, 34), (127, DECK_Z), (TRASEIRA_X, DECK_Z)])
        .close()
        .extrude(100)
        .val()
    )
    entrada = caixa(-ENTRADA_X / 2, ENTRADA_X / 2, -ENTRADA_Y / 2, ENTRADA_Y / 2,
                    EIXO_Z - 1, DECK_Z + 1)
    mancal_frontal = cilindro_x(DIAMETRO_MANCAL, FIM_CAMARA_X - 1, 116)
    furos_verticais = [
        cq.Solid.makeCylinder(1.65, 13, (x, y, DECK_Z - 12))
        for x, y in FUROS_RESERVATORIO
    ]
    furos_traseiros = [
        cilindro_x(3.3, TRASEIRA_X - 1, TRASEIRA_X + 15, y, EIXO_Z + z)
        for y, z in FUROS_TRASEIROS
    ]
    return base.fuse(carenagem).cut(
        camara(), entrada, canal_descarga(), mancal_frontal,
        *furos_verticais, *furos_traseiros
    ).clean()


def ponto_polar(raio, angulo):
    return raio * cos(radians(angulo)), raio * sin(radians(angulo))


def rosca():
    # O setor gira uma volta por passo. 45° na borda dão 4 mm de espessura axial.
    # A raiz mais larga reforça a junção da lâmina com o núcleo.
    raiz = RAIO_NUCLEO - 1
    helicoide = (
        cq.Workplane("XY")
        .moveTo(*ponto_polar(RAIO_ROSCA, -22.5))
        .threePointArc((RAIO_ROSCA, 0), ponto_polar(RAIO_ROSCA, 22.5))
        .lineTo(*ponto_polar(raiz, 34))
        .threePointArc((raiz, 0), ponto_polar(raiz, -34))
        .close()
        .twistExtrude(COMPRIMENTO_HELICE, 360 * COMPRIMENTO_HELICE / PASSO)
        .val()
        .rotate((0, 0, 0), (0, 1, 0), 90)
        .translate((INICIO_HELICE_X, 0, EIXO_Z))
    )
    nucleo = cilindro_x(2 * RAIO_NUCLEO, TRASEIRA_X + 0.5, FIM_CAMARA_X - 0.5)
    eixo = cilindro_x(DIAMETRO_PONTA, -96, 114.5)
    return nucleo.fuse(eixo, helicoide).clean()


def placa_traseira():
    x0 = TRASEIRA_X - ESPESSURA_PLACA
    placa = caixa(x0, TRASEIRA_X, -45, 45, EIXO_Z - 38, EIXO_Z + 38)
    furos = [
        cilindro_x(4.5, x0 - 1, TRASEIRA_X + 1, y, EIXO_Z + z)
        for y, z in FUROS_TRASEIROS
    ]
    return placa.cut(cilindro_x(DIAMETRO_MANCAL, x0 - 1, TRASEIRA_X + 1), *furos)


def suporte_motor():
    x0 = FACE_MOTOR_X
    x1 = TRASEIRA_X - ESPESSURA_PLACA
    frente = caixa(x0, x1, -45, 45, EIXO_Z - 38, EIXO_Z + 38)
    vazio = caixa(x0 + 7, x1 + 1, -41, 41, EIXO_Z - 34, EIXO_Z + 34)
    postes = [
        cilindro_x(14, x0 + 6, x1, y, EIXO_Z + z)
        for y, z in FUROS_TRASEIROS
    ]
    furos_m4 = [
        cilindro_x(4.5, x0 - 1, x1 + 1, y, EIXO_Z + z)
        for y, z in FUROS_TRASEIROS
    ]
    furos_m3 = [
        cilindro_x(3.4, x0 - 1, x0 + 8, y, EIXO_Z + z)
        for y, z in FUROS_NEMA17
    ]
    acesso_chave = caixa(-111, -85, 40, 46, EIXO_Z - 2.5, EIXO_Z + 2.5)
    return frente.cut(vazio).fuse(*postes).cut(
        cilindro_x(24, x0 - 1, x0 + 8), acesso_chave, *furos_m4, *furos_m3
    ).clean()


def tigela():
    fundo = (
        cq.Workplane("XY")
        .ellipse(66, 79)
        .workplane(offset=28)
        .ellipse(75, 88)
        .loft(ruled=True)
        .val()
    )
    cavidade = (
        cq.Workplane("XY", origin=(0, 0, 4))
        .ellipse(62.5, 75.5)
        .workplane(offset=25)
        .ellipse(71.5, 84.5)
        .loft(ruled=True)
        .val()
    )
    return fundo.cut(cavidade).translate((147, 0, 0))


def para_impressao(forma, rotacao=None):
    if rotacao is not None:
        eixo, angulo = rotacao
        forma = forma.rotate((0, 0, 0), eixo, angulo)
    caixa_limite = forma.BoundingBox()
    return forma.translate((
        -(caixa_limite.xmin + caixa_limite.xmax) / 2,
        -(caixa_limite.ymin + caixa_limite.ymax) / 2,
        -caixa_limite.zmin,
    ))


def montar_pecas():
    deposito, litros = reservatorio()
    eixo_x_na_vertical = ((0, 1, 0), -90)
    pecas = {
        "01-corpo": (corpo(), None, "#474D56"),
        "02-reservatorio": (deposito, None, "#DFE5E5"),
        "03-tampa": (tampa(), ((1, 0, 0), 180), "#697D80"),
        "04-rosca": (rosca(), eixo_x_na_vertical, "#D5895D"),
        "05-placa-traseira": (placa_traseira(), eixo_x_na_vertical, "#697D80"),
        "06-suporte-motor": (suporte_motor(), eixo_x_na_vertical, "#474D56"),
        "07-tigela": (tigela(), None, "#697D80"),
    }
    return pecas, litros


def gerar(destino):
    pecas, litros = montar_pecas()
    base = pecas["01-corpo"][0]
    if litros * DENSIDADE_KG_L < META_KG:
        raise ValueError("O reservatório ficou abaixo da capacidade-alvo.")
    envelope = cilindro_x(
        2 * RAIO_ROSCA + 0.2, INICIO_HELICE_X - 0.5, INICIO_HELICE_X + COMPRIMENTO_HELICE + 0.5
    )
    if base.intersect(envelope).Solids():
        raise ValueError("A hélice pode encostar na carcaça durante o giro.")
    montado = cq.Assembly(name="alimentador")
    malhas = {}
    for nome, (forma, rotacao, cor) in pecas.items():
        if not forma.isValid() or len(forma.Solids()) != 1:
            raise ValueError(f"{nome}: esperava um único sólido válido.")
        imprimivel = para_impressao(forma, rotacao)
        volume = imprimivel.BoundingBox()
        medidas = (volume.xlen, volume.ylen, volume.zlen)
        if any(medida > limite + 1e-5 for medida, limite in zip(medidas, MESA)):
            raise ValueError(f"{nome}: peça de {medidas} excede a mesa de {MESA} mm.")
        print(f"{nome:20s} {' x '.join(f'{m:.1f}' for m in medidas)} mm")
        malhas[nome] = imprimivel
        montado.add(forma, name=nome, color=cq.Color(cor))

    for (nome_a, (a, _, _)), (nome_b, (b, _, _)) in combinations(pecas.items(), 2):
        intersecao = a.intersect(b)
        if any(solido.Volume() > 0.01 for solido in intersecao.Solids()):
            raise ValueError(f"Interferência na montagem: {nome_a} e {nome_b}.")

    pasta_stl = destino / "stl"
    pasta_stl.mkdir(parents=True, exist_ok=True)
    caminhos_stl = []
    for nome, forma in malhas.items():
        caminho = pasta_stl / f"{nome}.stl"
        forma.exportStl(str(caminho), tolerance=0.06, angularTolerance=0.12)
        caminhos_stl.append(caminho)
    with ZipFile(destino / "alimentador-stl.zip", "w", compression=ZIP_DEFLATED) as pacote:
        for caminho in caminhos_stl:
            pacote.write(caminho, arcname=caminho.name)
    montado.export(str(destino / "alimentador.step"))
    print(f"Volume útil: {litros:.2f} L ({litros * DENSIDADE_KG_L:.2f} kg a {DENSIDADE_KG_L:.2f} kg/L).")
    print(f"Arquivos gerados em {destino.resolve()}")


# O CQ-Editor fornece show_object ao executar o script pelo botão Render.
mostrar = globals().get("show_object")
if callable(mostrar):
    pecas, _ = montar_pecas()
    for nome, (forma, _, cor) in pecas.items():
        mostrar(forma, name=nome, options={"color": cor})
elif __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--saida", type=Path, default=Path(__file__).resolve().parent / "export")
    gerar(parser.parse_args().saida)
